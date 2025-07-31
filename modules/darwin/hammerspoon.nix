{
  system.defaults.CustomSystemPreferences."org.hammerspoon.Hammerspoon".MJConfigFile = "~/.config/hammerspoon/init.lua";

  homebrew.casks = [ "hammerspoon" ];

  home-manager.sharedModules = [{
    xdg.configFile."hammerspoon/init.lua".text = "";
  }];
}
