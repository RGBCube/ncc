lib: lib.nixosSystem' ({ config, keys, lib, ... }: let
  inherit (lib) collectNix remove;
in {
  imports = collectNix ./.
    |> remove ./default.nix;

  secrets.id.file           = ./id.age;
  services.openssh.hostKeys = [{
    type = "ed25519";
    path = config.secrets.id.path;
  }];

  secrets.password.file = ./password.age;
  users.users           = {
    root = {
      openssh.authorizedKeys.keys = keys.admins;
      hashedPasswordFile          = config.secrets.password.path;
    };

    the = {
      description                 = "The";
      openssh.authorizedKeys.keys = keys.admins;
      hashedPasswordFile          = config.secrets.password.path;
      isNormalUser                = true;
      extraGroups                 = [ "wheel" ];
    };

    backup = {
      description                 = "Backup";
      openssh.authorizedKeys.keys = keys.all;
      hashedPasswordFile          = config.secrets.password.path;
      isNormalUser                = true;
    };

    build = {
      description                 = "Build";
      openssh.authorizedKeys.keys = keys.all;
      hashedPasswordFile          = config.secrets.password.path;
      isNormalUser                = true;
      extraGroups                 = [ "build" ];
    };
  };

  home-manager.users = {
    root   = {};
    the    = {};
    backup = {};
  };

  networking = let
    interface = "ens3";
  in {
    hostName = "best";

    ipv4.address = "152.53.236.46";
    ipv6.address = "2a0a:4cc0:c0:6c66::";

    domain = "rgbcu.be";

    defaultGateway = {
      inherit interface;

      address = "152.53.236.1";
    };

    defaultGateway6 = {
      inherit interface;

      address = "fe80::1";
    };
  };

  system.stateVersion        = "25.05";
  home-manager.sharedModules = [{
    home.stateVersion = "25.05";
  }];
})
