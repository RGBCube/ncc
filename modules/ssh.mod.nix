{ self, ... }:
{
  flake.homeModules.ssh-client =
    { config, lib, ... }:
    let
      inherit (lib.attrsets)
        attrNames
        attrValues
        filterAttrs
        getAttr
        mapAttrs
        ;
      inherit (lib.lists) head remove singleton;
      inherit (lib.strings) concatLines;

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
              User ${
                config.users.users
                |> filterAttrs (_: user: user.isNormalUser)
                |> attrNames
                |> remove "backup"
                |> remove "build"
                |> remove "root"
                |> head
              }
              HostName ${
                config.networking.interfaces
                |> attrValues
                |> head
                |> (value: value.ipv4.addresses)
                |> head
                |> getAttr "address"
              }
              Port ${head config.services.openssh.ports}
          ''
        );
    in
    {
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
                  IdentityFile ${config.xdg.config.directory}/id

                  SetEnv COLORTERM=truecolor TERM=xterm256-color

                  ControlMaster auto
                  ControlPersist 60m
                  ControlPath ${config.xdg.cache.directory}/ssh/%r@%n:%p
              '';

      # Create that directory. I don't think hjem has a better way of doing this.
      xdg.cache.files."ssh/.keep".text = "";
    };

  flake.homeModules.ssh-client-desktop =
    { pkgs, ... }:
    {
      packages = [
        pkgs.mosh
      ];

      programs.nushell.aliases.mosh = "mosh --no-init";
    };

  flake.nixosModules.ssh-server = {
    programs.mosh = {
      enable = true;
      openFirewall = true;
    };

    services.openssh = {
      enable = true;
      ports = [ 2222 ];
      settings = {
        KbdInteractiveAuthentication = false;
        PasswordAuthentication = false;

        AcceptEnv = "SHELLS COLORTERM";
      };
    };
  };
}
