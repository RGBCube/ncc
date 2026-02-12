{
  flake.homeModules.whatsapp =
    { pkgs, ... }:
    {
      packages = [
        pkgs.wasistlos
      ];
    };
}
