{
  flake.darwinModules.hammerspoon =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      system.defaults.CustomSystemPreferences."org.hammerspoon.Hammerspoon".MJConfigFile =
        "~/.config/hammerspoon/init.lua";

      homebrew.casks = singleton "hammerspoon";
    };

  flake.homeModules.hammerspoon =
    { lib, osConfig, ... }:
    let
      inherit (lib.modules) mkIf;
    in
    {
      xdg.config.files."hammerspoon/init.lua".text = mkIf osConfig.nixpkgs.hostPlatform.isDarwin "";
    };
}
