{
  system.defaults.CustomSystemPreferences."org.hammerspoon.Hammerspoon".MJConfigFile = "~/.config/hammerspoon/init.lua";

  home-manager.sharedModules = [{
    xdg.configFile."hammerspoon/init.lua".text = "";
  }];
}
