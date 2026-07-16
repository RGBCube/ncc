{ self, ... }:
{
  flake.darwinModules.media = self.darwinModules.obs-studio;
  flake.darwinModules.obs-studio =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      homebrew.casks = singleton "obs";
    };

  flake.homeModules.media = self.homeModules.obs-studio;
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
