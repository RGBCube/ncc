{ self, config, lib, pkgs, ... }: let
  inherit (lib) enabled mkIf filterAttrs attrNames mapAttrs head remove;

  controlPath = "~/.ssh/control";

  hosts = self.nixosConfigurations
    |> filterAttrs (_: value: value.config.services.openssh.enable)
    |> mapAttrs (_: value: {
      user = value.config.users.users
        |> filterAttrs (_: value: value.isNormalUser)
        |> attrNames
        |> remove "backup"
        |> remove "build"
        |> remove "root"
        |> head;

      hostname = value.config.networking.ipv4.address;

      port = head value.config.services.openssh.ports;
    });
in {
  secrets.sshConfig = {
    file = ./config.age;
    mode = "444";
  };

  home-manager.sharedModules = [(homeArgs: let
    lib' = homeArgs.lib;

    inherit (lib'.hm.dag) entryAfter;
  in {
    home.activation.createControlPath = entryAfter [ "writeBoundary" ] /* bash */ ''
      mkdir --parents ${controlPath}
    '';

    programs.ssh = enabled {
      controlMaster       = "auto";
      controlPath         = "${controlPath}/%r@%n:%p";
      controlPersist      = "60m";
      serverAliveCountMax = 2;
      serverAliveInterval = 60;

      includes = [ config.secrets.sshConfig.path ];

      matchBlocks = hosts // {
        "*" = {
          setEnv.COLORTERM = "truecolor";
          setEnv.TERM      = "xterm-256color";

          identityFile = "~/.ssh/id";
        };
      };
    };
  })];

  environment = mkIf config.isDesktop {
    systemPackages    = [ pkgs.mosh ];
    shellAliases.mosh = "mosh --no-init";
  };
}
