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
    let
      inherit (lib.lists) singleton;

      stats = pkgs.stats.overrideAttrs {
        version = "3.0.9";

        src = pkgs.fetchFromGitHub {
          owner = "exelban";
          repo = "Stats";
          tag = "v3.0.9";
          hash = "sha256-ioppiSutvke15vVcWdEBCSw/BAv7BYjkk8pR5D6goMg=";
        };
      };
    in
    {
      environment.systemPackages = singleton stats;

      system.defaults.CustomSystemPreferences."eu.exelban.Stats" = {
        update-interval = "Never";
        setupProcess = 1;

        CPU_widget = "line_chart,label";
        CPU_line_chart_box = 0;

        GPU_state = 1;
        GPU_widget = "line_chart,label";
        GPU_line_chart_box = 0;

        RAM_widget = "line_chart,label";
        RAM_line_chart_box = 0;

        Disk_state = 0;

        Battery_state = 0;
      };

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

      system.defaults.CustomSystemPreferences."com.apple.dock" = {
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
