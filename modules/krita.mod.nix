{
  flake.darwinModules.krita = {
    homebrew.casks = [ "krita" ];
  };

  flake.homeModules.krita =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.modules) mkIf;
    in
    {
      packages = mkIf config.nixpkgs.hostPlatform.isLinux [
        pkgs.krita
      ];
    };
}
