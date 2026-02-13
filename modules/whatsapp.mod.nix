{
  flake.darwinModules.whatsapp = {
    homebrew.casks = [ "whatsapp" ];
  };

  flake.homeModules.whatsapp =
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
        pkgs.wasistlos
      ];
    };
}
