{
  flake.darwinModules.hammerspoon = {
    system.defaults.CustomSystemPreferences."org.hammerspoon.Hammerspoon".MJConfigFile =
      "~/.config/hammerspoon/init.lua";

    homebrew.casks = [ "hammerspoon" ];
  };

  flake.homeModules.hammerspoon =
    { config, lib, ... }:
    let
      inherit (lib.modules) mkIf;
    in
    {
      xdg.config.file."hammerspoon/init.lua".text = mkIf config.nixpkgs.hostPlatform.isDarwin "";
    };
}
