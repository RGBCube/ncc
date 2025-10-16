{
  homeModules.obs-studio =
    { pkgs, ... }:
    {
      packages = [
        pkgs.obs-studio 
      ];
    };
}
