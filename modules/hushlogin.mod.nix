{
  flake.homeModules.hushlogin =
    { lib, osConfig, ... }:
    let
      inherit (lib.modules) mkIf;
    in
    {
      files.".hushlogin".text = mkIf osConfig.nixpkgs.hostPlatform.isDarwin "";
    };
}
