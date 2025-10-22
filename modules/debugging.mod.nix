{ self, ... }:
{
  nixosModules.debugging =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.strace
        self.packages.x86_64-linux.ida-pro
      ];

      nixpkgs.config.allowedUnfreePackageNames = [ "ida-pro" ];
    };
}
