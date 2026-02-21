{
  flake.darwinModules.krita =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      homebrew.casks = singleton "krita";
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
