{ self, ... }:
{
  flake.homeModules.default = self.homeModules.ssh-client;
  flake.homeModules.ssh-client =
    {
      config,
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) filterAttrs mapAttrs;
      inherit (lib.generators) toSSHConfig;
      inherit (lib.lists) head;
      inherit (lib.meta) getExe';
      inherit (lib.modules) mkAfter;
      inherit (lib.strings) optionalString;

      echo = getExe' pkgs.uutils-coreutils-noprefix "echo";
    in
    {
      xdg.config.files."ssh/config".generator = toSSHConfig;
      xdg.config.files."ssh/config".value.Host =
        (
          self.nixosConfigurations
          |> filterAttrs (_: { config, ... }: config.services.openssh.enable)
          |> mapAttrs (
            name:
            { config, ... }:
            {
              User = "root";
              Port = head config.services.openssh.ports;
              KnownHostsCommand = ''${echo} "%H ${self.machines.${name}.key}"'';
            }
          )
        )
        // {
          best = {
            User = "root";
            HostName = "rgbcu.be";
            Port = 2222;
            KnownHostsCommand = ''${echo} "%H ${self.machines.best.key}"'';
          };

          "*" = {
            SetEnv = "COLORTERM=truecolor TERM=xterm-256color";

            ControlMaster = "auto";
            ControlPersist = "60m";
            ControlPath = "${config.xdg.cache.directory}/ssh/%r@%n:%p";
          };
        };

      xdg.cache.files."ssh".type = "directory";

      programs.nushell.extraConfig =
        mkAfter
        <| optionalString osConfig.nixpkgs.hostPlatform.isDarwin "source ${
          pkgs.writeText "ssh-auth-sock.nu" /* nu */ ''
            try {
              $env.SSH_AUTH_SOCK = ^launchctl getenv SSH_AUTH_SOCK | str trim
            }
          ''
        }";
    };

  flake.homeModules.desktop = self.homeModules.ssh-client-desktop;
  flake.homeModules.ssh-client-desktop =
    { pkgs, ... }:
    {
      packages = [
        pkgs.mosh
      ];

      programs.nushell.aliases.mosh = "mosh --no-init";
    };

  flake.nixosModules.server.imports = [
    self.nixosModules.ssh-server
    self.nixosModules.endlessh-go
  ];
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
      inherit (lib.lists) singleton;
    in
    {
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
      };
    };
}
