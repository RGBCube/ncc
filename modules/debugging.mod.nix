{ self, ... }:
{
  flake.nixosModules.debugging-gui =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        self.packages.x86_64-linux.ida-pro
      ];

      allowedUnfreePackageNames = [ "ida-pro" ];
    };

  flake.nixosModules.debugging =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.strace
        pkgs.usbutils
      ];
    };
}
