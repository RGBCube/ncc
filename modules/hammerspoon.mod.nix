{
  flake.darwinModules.hammerspoon = {
    system.defaults.CustomSystemPreferences."org.hammerspoon.Hammerspoon".MJConfigFile =
      "~/.config/hammerspoon/init.lua";

    homebrew.casks = [ "hammerspoon" ];
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
