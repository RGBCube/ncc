{
  flake.nixosModules.steam =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      allowedUnfreePackageNames = singleton "steam";

      programs.steam.enable = true;
    };
}
