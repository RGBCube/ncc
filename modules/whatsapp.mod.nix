{
  homeModules.whatsapp =
    { pkgs, ... }:
    {
      packages = [
        pkgs.whatsapp-for-linux
      ];
    };
}
