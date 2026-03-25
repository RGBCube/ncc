{
  flake.darwinModules.syncthing =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      homebrew.casks = singleton "syncthing-app";
    };

  flake.nixosModules.syncthing =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      persist.paths = singleton "/var/lib/syncthing";

      services.syncthing.enable = true;
    };
}
