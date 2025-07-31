lib: lib.darwinSystem' ({ config, lib, ... }: let
  inherit (lib) collectNix remove;
in {
  imports = collectNix ./.
    |> remove ./default.nix;

  type = "desktop";

  secrets.id.file      = ./id.age;
  secrets.id-cull.file = ./id-cull.age;
  secrets.id-no.file   = ./id-no.age;

  services.openssh.extraConfig = /* sshclientconfig */ ''
    HostKey ${config.secrets.id.path}
    HostKey ${config.secrets.id-cull.path}
    HostKey ${config.secrets.id-no.path}
  '';

  networking.hostName = "pala";

  users.users.pala = {
    name = "Pala";
    home = "/Users/pala";
  };

  home-manager.users.pala.home = {
    stateVersion  = "25.05";
    homeDirectory = config.users.users.pala.home;
  };

  system.stateVersion = 5;
})
