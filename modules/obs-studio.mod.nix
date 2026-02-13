{

  flake.darwinModules.obs-studio = {
    homebrew.casks = [ "obs" ];
  };

  flake.homeModules.obs-studio =
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
        pkgs.obs-studio 
      ];
    };
}
