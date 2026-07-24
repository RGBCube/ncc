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
      inherit (lib.lists) head singleton;
      inherit (lib.meta) getExe';
      inherit (lib.modules) mkAfter;
      inherit (lib.strings) optionalString;

      echo = getExe' pkgs.uutils-coreutils-noprefix "echo";
    in
    {
      packages = singleton pkgs.openssh;

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

      xdg.config.files."nushell/config.nu".text =
        mkAfter
        <| optionalString osConfig.nixpkgs.hostPlatform.isDarwin "source ${
          pkgs.writeText "ssh-auth-sock.nu" /* nu */ ''
            try {
              $env.SSH_AUTH_SOCK = /bin/launchctl getenv SSH_AUTH_SOCK | str trim
            }
          ''
        }";
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

  flake.nixosModules.default = self.nixosModules.ssh-server;
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

      users.users.root.openssh.authorizedKeys.keys = self.keys-admin;
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
          package = pkgs.endlessh-go;
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
}
