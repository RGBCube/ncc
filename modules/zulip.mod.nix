{
  flake.darwinModules.zulip = {
    homebrew.casks = [ "zulip" ];
  };

  flake.homeModules.zulip =
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
        pkgs.zulip
      ];
    };
}
