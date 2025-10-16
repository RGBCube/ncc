{
  homeModules.thunderbird =
    { pkgs, ... }:
    {
      packages = [
        pkgs.thunderbird 
      ];
    };
}
