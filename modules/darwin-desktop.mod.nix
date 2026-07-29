{ self, ... }:
{
  flake.darwinModules.desktop = self.darwinModules.darwin-desktop;
  flake.darwinModules.darwin-desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # DOCK
      system.defaults.dock = {
        autohide = true;
        showhidden = true;

        mouse-over-hilite-stack = true;

        show-recents = false;
        mru-spaces = false;

        tilesize = 48;
        magnification = false;

        enable-spring-load-actions-on-all-items = true;
      };

      system.defaults.CustomUserPreferences."com.apple.dock" = {
        autohide-time-modifier = 0.0;
        autohide-delay = 0.0;
        expose-animation-duration = 0.0;
        springboard-show-duration = 0.0;
        springboard-hide-duration = 0.0;
        springboard-page-duration = 0.0;

        # Disable hot corners.
        wvous-tl-corner = 0;
        wvous-tr-corner = 0;
        wvous-bl-corner = 0;
        wvous-br-corner = 0;

        launchanim = 0;
      };

      # MENU BAR
      system.defaults.menuExtraClock.Show24Hour = true;
      system.defaults.menuExtraClock.ShowSeconds = true;

      system.defaults.controlcenter.BatteryShowPercentage = true;
      system.defaults.controlcenter.Bluetooth = true;

      # HIDE FROM MENU BAR: DISPLAY, KEYBOARD LOCALE, SPOTLIGHT SEARCH
      system.defaults.controlcenter.Display = false;
      system.defaults.CustomUserPreferences."com.apple.TextInputMenu".visible = false;
      system.activationScripts.postActivation.text = "${pkgs.writers.writeNu "hide-spotlight.nu" /* nu */ ''
        let user = r###'${config.system.primaryUser}'###
        let uid = sys users | where name == $user | get 0.id

        (^/bin/launchctl asuser $uid /usr/bin/sudo
          --set-home
          --user $user
          --
          /usr/bin/defaults
          -currentHost write com.apple.Spotlight MenuItemHidden -int 1)

        try {
          (^/bin/launchctl asuser $uid /usr/bin/sudo
            --set-home
            --user $user
            --
            /usr/bin/killall TextInputMenuAgent)
        }
      ''}";

      # SCREENSHOTS
      system.defaults.screencapture.location = "~/Downloads";

      # TRACKPAD
      system.defaults.trackpad = {
        Clicking = false;
        Dragging = false;
      };
    };
}
