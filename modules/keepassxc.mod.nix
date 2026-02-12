{
  flake.darwinModules.keepassxc = {
    homebrew.casks = [ "keepassxc" ];
  };

  flake.homeModules.keepassxc =
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
        pkgs.keepassxc
      ];
    };
}
