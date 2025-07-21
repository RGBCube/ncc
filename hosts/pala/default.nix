lib: lib.darwinSystem' ({ config, lib, ... }: let
  inherit (lib) collectNix remove;
in {
  imports = collectNix ./.
    |> remove ./default.nix;

  type = "desktop";

  networking.hostName = "pala";

  users.users.pala = {
    name = "pala";
    home = "/Users/pala";
  };

  home-manager.users.pala.home = {
    stateVersion  = "25.05";
    homeDirectory = config.users.users.pala.home;
  };

  system.stateVersion = 5;
})
