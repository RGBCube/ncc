{
  homeModules.krita =
    { pkgs, ... }:
    {
      packages = [
        pkgs.krita 
      ];
    };
}
