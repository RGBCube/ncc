{
  flake.homeModules.hushlogin =
    { lib, osConfig, ... }:
    let
      inherit (lib.modules) mkIf;
    in
    {
      files.".hushlogin" = mkIf osConfig.nixpkgs.hostPlatform.isDarwin { text = ""; };
    };
}
