{
  flake.homeModules.libreoffice =
    { pkgs, ... }:
    {
      packages = [
        pkgs.libreoffice
        pkgs.hunspellDicts.en_US
        pkgs.hunspellDicts.en_GB-ize
      ];
    };
}
