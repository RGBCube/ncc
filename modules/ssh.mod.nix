{ self, ... }:
{
  flake.homeModules.ssh-client =
    {
      config,
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets)
        attrValues
        filterAttrs
        mapAttrs
        ;
      inherit (lib.lists) head singleton;
      inherit (lib.modules) mkAfter;
      inherit (lib.strings) concatLines optionalString;

      hosts =
        self.nixosConfigurations
        |> filterAttrs (_: value: value.config.services.openssh.enable)
        |> mapAttrs (
          name: value:
          let
            inherit (value) config;
          in
          # sshclientconfig
          ''
            Host ${name}
              User root
              # Tailscale.
              HostName ${name}
              Port ${toString <| head config.services.openssh.ports}
          ''
        );
    in
    {
      xdg.config.files."ssh/config".text =
        concatLines
        <|
          attrValues hosts
          ++
            singleton
              # sshclientconfig
              ''
                Host best
                  User root
                  HostName rgbcu.be
                  Port 2222
              ''
          ++
            singleton
              # sshclientconfig
              ''
                Host *
                    SetEnv COLORTERM=truecolor TERM=xterm-256color

                    ControlMaster auto
                    ControlPersist 60m
                    ControlPath ${config.xdg.cache.directory}/ssh/%r@%n:%p
              '';

      xdg.cache.files."ssh".type = "directory";

      programs.nushell.extraConfig =
        mkAfter
        <| optionalString osConfig.nixpkgs.hostPlatform.isDarwin "source ${
          pkgs.writeText "ssh-auth-sock.nu" /* nu */ ''
            try {
              $env.SSH_AUTH_SOCK = ^launchctl getenv SSH_AUTH_SOCK | str trim
            }
          ''
        }\n";
    };

  flake.homeModules.ssh-client-desktop =
    { pkgs, ... }:
    {
      packages = [
        pkgs.mosh
      ];

      programs.nushell.aliases.mosh = "mosh --no-init";
    };

  flake.nixosModules.ssh-server =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) head singleton;
      inherit (lib.modules) mkForce;
    in
    {
      programs.mosh.enable = true;

      services.openssh = {
        enable = true;
        ports = singleton 2222;

        hostKeys =
          config.age.identityPaths
          |> map (path: {
            type = "ed25519";
            inherit path;
          });

        settings = {
          KbdInteractiveAuthentication = false;
          PasswordAuthentication = false;

          AcceptEnv = [
            "SHELLS"
            "COLORTERM"
          ];
        };
      };

      users.users.root.openssh.authorizedKeys.keys = self.keys-admin;

      boot.initrd.systemd.network = {
        enable = true;
        networks."10-wired" = {
          matchConfig.Type = "ether";
          networkConfig.DHCP = "yes";
        };
      };

      boot.initrd.network.ssh = {
        enable = true;
        port = head config.services.openssh.ports;

        hostKeys = config.age.identityPaths |> map (path: "/sysroot${path}");
        authorizedKeys = config.users.users.root.openssh.authorizedKeys.keys;
      };

      boot.initrd.systemd.services.sshd = {
        unitConfig.RequiresMountsFor = config.boot.initrd.network.ssh.hostKeys;

        # Nixpkgs tries to run `chmod`, but the key is on a readonly partition so it fails.
        #
        # Nuke it.
        preStart = mkForce "";
      };

      # The `hostKey` is already a runtime path, not a Nix store path.
      boot.initrd.secrets = mkForce { };
    };

  flake.nixosModules.endlessh-go =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.options) mkEnableOption mkOption;
      inherit (lib.types) str port;
      inherit (lib.lists) singleton;
    in
    {
      # And yes, I've tried lib.mkAliasOptionModule.
      # It doesn't work for a mysterious reason,
      # says it can't find `services.prometheus.exporters.endlessh-go`.
      #
      # This works, however.
      #
      # TODO: I may be stupid, because the above note says that I tried
      # to alias to a nonexistent option, rather than the other way around.
      # Let's try mkAliasOptionModule again later.
      options.services.prometheus.exporters.endlessh-go = {
        enable = mkEnableOption "Prometheus integration";

        listenAddress = mkOption {
          type = str;
          default = "0.0.0.0";
        };

        port = mkOption {
          type = port;
          default = 2112;
        };
      };

      config.services.prometheus.exporters.endlessh-go = {
        enable = true;

        listenAddress = "[::]";
      };

      # `services.endlessh-go.openFirewall` exposes both the Prometheus
      # exporters port and the SSH port, and we don't want the metrics
      # to leak, so we manually expose this like so.
      config.networking.firewall.allowedTCPPorts = singleton config.services.endlessh-go.port;

      config.services.endlessh-go = {
        enable = true;

        listenAddress = "[::]";
        port = 22;

        extraOptions = [
          "-alsologtostderr"
          "-geoip_supplier max-mind-db"
          "-max_mind_db ${pkgs.dbip-country-lite}/share/dbip/dbip-country-lite.mmdb"
        ];

        prometheus = config.services.prometheus.exporters.endlessh-go;
      };
    };
}
