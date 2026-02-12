{
  flake.homeModules.matrix =
    { pkgs, ... }:
    {
      packages = [
        pkgs.cinny-desktop
      ];
    };
}
