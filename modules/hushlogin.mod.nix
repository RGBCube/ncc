{
  flake.homeModules.hushlogin =
    { config, lib, ... }:
    let
      inherit (lib.modules) mkIf;
    in
    {
      file.".hushlogin".text = mkIf config.nixpkgs.hostPlatform.isDarwin "";
    };
}
