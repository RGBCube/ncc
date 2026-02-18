{
  flake.darwinModules.keepassxc =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      homebrew.casks = singleton "keepassxc";
    };

  flake.homeModules.keepassxc =
    {
      osConfig,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.modules) mkIf;

      # TODO: Re-enable package override after upstream darwin YubiKey build is fixed.
      # package = pkgs.keepassxc.override {
      #   withKeePassYubiKey = true;
      # };
    in
    {
      packages = mkIf osConfig.nixpkgs.hostPlatform.isLinux [
        pkgs.keepassxc
      ];
    };
}
