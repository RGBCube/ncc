{ self, ... }:
{
  flake.darwinModules.desktop = self.darwinModules.hammerspoon;
  flake.darwinModules.hammerspoon =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      homebrew.casks = singleton "hammerspoon";

      system.defaults.CustomUserPreferences."org.hammerspoon.Hammerspoon" = {
        MJConfigFile = "~/.config/hammerspoon/init.lua";

        SUEnableAutomaticChecks = false;
        SUAutomaticallyUpdate = false;
        SUSendProfileInfo = false;
      };

      launchd.user.agents.hammerspoon.serviceConfig = {
        RunAtLoad = true;
        ProgramArguments = [
          "/usr/bin/open"
          "-a"
          "/Applications/Hammerspoon.app"
        ];
      };
    };

  flake.homeModules.hammerspoon =
    { lib, osConfig, ... }:
    let
      inherit (lib.modules) mkIf;
    in
    {
      xdg.config.files."hammerspoon/init.lua" = mkIf osConfig.nixpkgs.hostPlatform.isDarwin {
        text = "";
      };
    };
}
