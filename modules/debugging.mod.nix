{ self, ... }:
{
  flake.nixosModules.debugging =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.strace
        pkgs.usbutils
        self.packages.x86_64-linux.ida-pro
      ];

      nixpkgs.config.allowedUnfreePackageNames = [ "ida-pro" ];
    };
}
