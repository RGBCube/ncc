{ self, ... }:
{
  flake.homeModules.default = self.homeModules.ssh-client;
  flake.homeModules.ssh-client =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) filterAttrs mapAttrs;
      inherit (lib.generators) toSSHConfig;
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe';
    in
    {
      packages = singleton pkgs.openssh;

      xdg.cache.files."ssh".type = "directory";

      xdg.config.files."ssh/config".generator = toSSHConfig;
      xdg.config.files."ssh/config".value.Host =
        (
          self.machines
          |> filterAttrs (_: { ssh, ... }: ssh.enable)
          |> mapAttrs (
            _:
            { ssh, ... }:
            {
              User = ssh.user;
              HostName = ssh.hostName;
              Port = ssh.port;
              KnownHostsCommand = ''${getExe' pkgs.uutils-coreutils-noprefix "echo"} "%H ${ssh.key}"'';
            }
          )
        )
        // {
          "*" = {
            SetEnv = "COLORTERM=truecolor TERM=xterm-256color";

            ControlMaster = "auto";
            ControlPersist = "60m";
            ControlPath = "${config.xdg.cache.directory}/ssh/%r@%n:%p";
          };
        };
    };

  flake.homeModules.desktop = self.homeModules.ssh-client-desktop;
  flake.homeModules.ssh-client-desktop =
    { pkgs, lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      packages = singleton pkgs.mosh;

      xdg.config.files."nushell/aliases.nu".value.mosh = "mosh --no-init";
    };

  flake.nixosModules.default.imports = [
    self.nixosModules.ssh-server
    self.nixosModules.ssh-agent
  ];

  flake.nixosModules.ssh-server =
    {
      config,
      lib,
      ...
    }:
    let
      inherit (lib.lists) singleton;
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

      users.users.root.openssh.authorizedKeys.keys = self.ssh-keys-admin;
    };

  flake.nixosModules.server = self.nixosModules.endlessh-go;
  flake.nixosModules.endlessh-go =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.magic) ula;
    in
    {
      networking.interfaces.lo.ipv6.addresses = singleton {
        address = config.system.services.endlessh-go.endlessh-go.settings.prometheus_host;
        prefixLength = 128;
      };

      systemd.services.endlessh-go = {
        after = singleton "network-addresses-lo.service";
        bindsTo = singleton "network-addresses-lo.service";
      };

      networking.firewall.allowedTCPPorts = config.system.services.endlessh-go.endlessh-go.settings.port;

      system.services.endlessh-go = {
        imports = singleton self.serviceModules.endlessh-go;

        endlessh-go = {
          # TODO: Stop overriding when go >= 1.27.
          package = pkgs.endlessh-go.override {
            buildGoModule = pkgs.buildGoModule.override { go = pkgs.go_1_27; };
          };

          settings = {
            host = "::";
            port = singleton 22;

            enable_prometheus = true;
            prometheus_host = "${ula "endlessh-go/prometheus"}::1";
            prometheus_port = 80;

            geoip_supplier = "max-mind-db";
            max_mind_db = "${pkgs.dbip-country-lite}/share/dbip/dbip-country-lite.mmdb";

            alsologtostderr = true;
          };
        };
      };
    };

  commonModules.ssh-agent =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets)
        attrNames
        filterAttrs
        getAttr
        ;
      inherit (lib.lists) singleton;
      inherit (lib.trivial) const;

      isDarwin = config.nixpkgs.hostPlatform.isDarwin;

      interactiveUsers =
        if isDarwin then
          singleton config.system.primaryUser
        else
          config.users.users |> filterAttrs (const <| getAttr "isNormalUser") |> attrNames;
    in
    {
      users.groups.ssh-agent.members = interactiveUsers;

      system.services.ssh-agent = {
        imports = singleton self.serviceModules.ssh-agent;

        ssh-agent = {
          inherit (pkgs.writers) writeNu;

          package = pkgs.openssh.overrideAttrs (old: {
            postPatch = (old.postPatch or "") + /* sh */ ''
              sed -i '0,/prev_mask = umask(0177);/s//prev_mask = umask(0007);/' ssh-agent.c
            '';
          });
        };
      };

      nix.envVars.SSH_AUTH_SOCK =
        if config.nixpkgs.hostPlatform.isDarwin then
          "/var/run/ssh-agent/socket"
        else
          "/run/ssh-agent/socket";
    };

  flake.nixosModules.ssh-agent = {
    environment.sessionVariables.SSH_AUTH_SOCK = "/run/ssh-agent/socket";
  };

  flake.darwinModules.default = self.darwinModules.ssh-agent;
  flake.darwinModules.ssh-agent = {
    # TODO: Remove hacks we do for shell init and use this, which is essentially Darwin environment.sessionVariables.
    launchd.user.envVariables.SSH_AUTH_SOCK = "/var/run/ssh-agent/socket";
  };
}
