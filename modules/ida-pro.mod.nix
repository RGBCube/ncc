{ self, ... }:
{
  flake.nixosModules.desktop = self.nixosModules.ida-pro;
  flake.nixosModules.ida-pro =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      nixpkgs.allowedUnfreePackages = singleton "ida-pro";

      environment.systemPackages = singleton self.packages.x86_64-linux.ida-pro;
    };
}
