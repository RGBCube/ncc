{
  flake.darwinModules.libreoffice = {
    homebrew.casks = [ "libreoffice" ];
  };

  flake.homeModules.libreoffice =
    {
      osConfig,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib.modules) mkIf;
    in
    {
      packages = mkIf osConfig.nixpkgs.hostPlatform.isLinux [
        pkgs.libreoffice
        pkgs.hunspellDicts.en_US
        pkgs.hunspellDicts.en_GB-ize
      ];
    };
}
