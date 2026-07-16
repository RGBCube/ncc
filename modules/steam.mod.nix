{ self, ... }:
{
  flake.nixosModules.gaming = self.nixosModules.steam;
  flake.nixosModules.steam =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      nixpkgs.allowedUnfreePackages = singleton "steam";

      programs.steam.enable = true;
    };
}
