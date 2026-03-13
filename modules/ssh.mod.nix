{ self, ... }:
{
  flake.homeModules.ssh-client =
    {
      config,
      lib,
      osConfig,
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
              ${
                # TODO:
                # config.networking.interfaces
                # |> attrValues
                # |> head
                # |> (value: value.ipv4.addresses)
                # |> head
                # |> getAttr "address"
                ""
              }
              Port ${toString <| head config.services.openssh.ports}
          ''
        );
    in
    {
      xdg.config.files."ssh/key.pub".text = /* ssh */ ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBVkWUQ6Z4OK539tore/R5wnueNPPaX532RUAld8UOCo rgbcube
      '';

      files.".ssh/config".text =
        # sshclientconfig
        ''
          Include ${config.xdg.config.directory}/ssh/config
        '';

      xdg.config.files."ssh/config".text =
        concatLines
        <|
          attrValues hosts
          ++
            singleton
              # sshclientconfig
              ''
                Host *
                  SetEnv COLORTERM=truecolor TERM=xterm256-color

                  ControlMaster auto
                  ControlPersist 60m
                  ControlPath ${config.xdg.cache.directory}/ssh/%r@%n:%p
              '';

      xdg.cache.files."ssh".type = "directory";

      programs.nushell.extraConfig =
        mkAfter
        <| optionalString osConfig.nixpkgs.hostPlatform.isDarwin /* nu */ ''
          try {
            $env.SSH_AUTH_SOCK = ^launchctl getenv SSH_AUTH_SOCK | str trim
          }
        '';
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
    { keys, lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      programs.mosh = {
        enable = true;
        openFirewall = true;
      };

      services.openssh = {
        enable = true;
        ports = singleton 2222;
        settings = {
          KbdInteractiveAuthentication = false;
          PasswordAuthentication = false;

          AcceptEnv = "SHELLS COLORTERM";
        };
      };

      users.users.root.openssh.authorizedKeys.keys = keys.admins;
    };
}
