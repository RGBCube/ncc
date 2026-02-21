{

  flake.darwinModules.obs-studio =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      homebrew.casks = singleton "obs";
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
