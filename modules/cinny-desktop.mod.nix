{
  homeModules.cinny-desktop =
    { pkgs, ... }:
    {
      packages = [
        pkgs.cinny-desktop
      ];
    };
}
