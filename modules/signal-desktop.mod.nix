{
  flake.darwinModules.signal-desktop = {
    homebrew.casks = [ "signal" ];
  };

  flake.homeModules.signal-desktop =
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
        pkgs.signal-desktop
      ];
    };
}
