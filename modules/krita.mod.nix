{
  flake.darwinModules.krita = {
    homebrew.casks = [ "krita" ];
  };

  flake.homeModules.krita =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      inherit (lib.modules) mkIf;
    in
    {
      packages = mkIf osConfig.nixpkgs.hostPlatform.isLinux [
        pkgs.krita
      ];
    };
}
