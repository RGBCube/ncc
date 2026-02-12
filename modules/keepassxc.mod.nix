{
  flake.darwinModules.keepassxc = {
    homebrew.casks = [ "keepassxc" ];
  };

  flake.homeModules.keepassxc =
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
        pkgs.keepassxc
      ];
    };
}
