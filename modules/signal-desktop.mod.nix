{
  flake.darwinModules.signal-desktop = {
    homebrew.casks = [ "signal" ];
  };

  flake.homeModules.signal-desktop =
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
        pkgs.signal-desktop
      ];
    };
}
