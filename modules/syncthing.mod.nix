{
  flake.darwinModules.syncthing = {
    homebrew.casks = [ "syncthing-app" ];
  };

  flake.nixosModules.syncthing = {
    services.syncthing.enable = true;
  };
}
