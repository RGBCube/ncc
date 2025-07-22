{ config, lib, pkgs, ... }: let
  inherit (lib) enabled merge mkIf flatten range;
in merge <| mkIf config.isDesktop {
  hardware.graphics = enabled;

  services.logind.powerKey = "ignore";

  xdg.portal = enabled {
    config.common.default = "*";

    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
    ];

    configPackages = [
      pkgs.hyprland
    ];
  };

  programs.xwayland = enabled;

  environment.systemPackages = [
    pkgs.brightnessctl
    pkgs.grim
    pkgs.hyprpicker
    pkgs.slurp
    pkgs.swappy
    pkgs.swaybg
    pkgs.wl-clipboard
    pkgs.wtype
    pkgs.xdg-utils
    pkgs.xwaylandvideobridge
  ];

  home-manager.sharedModules = [{
    wayland.windowManager.hyprland = enabled {
      systemd = enabled {
        enableXdgAutostart = true;
      };

      # plugins = [ pkgs.hyprcursors ];

      # settings.plugin.dynamic-cursors = {
      #   mode  = "rotate";

      #   shake = {
      #     threshold = 3;

      #     effects = true;
      #     nearest = false;
      #   };
      # };

      settings = {
        monitor = [ ", preferred, auto, 1.5" ];

        windowrule   = [ "noinitialfocus" ];
        windowrulev2 = [ "workspace special silent, initialclass:^(xwaylandvideobridge)$" ];

        exec = [ "pkill swaybg; swaybg --image ${./wallpaper.png}" ];

        bindle = [
          ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 1.5"
          ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"

          ", XF86MonBrightnessUp  , exec, brightnessctl set 5%+"
          ", XF86MonBrightnessDown, exec, brightnessctl set --min-value=0 5%-"

          "SUPER, Prior, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 1.5"
          "SUPER, Next , exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"

          "SUPER, Home, exec, brightnessctl set 5%+"
          "SUPER, End , exec, brightnessctl set --min-value=0 5%-"
        ];

        bindl = [
          ", XF86AudioMute   , exec, wpctl set-mute @DEFAULT_AUDIO_SINK@   toggle"
          ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"

          "SUPER+SHIFT, Insert, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@   toggle"
          "SUPER+SHIFT, Delete, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ];

        bindm = [
          "SUPER, mouse:272, movewindow"
          "SUPER, mouse:274, movewindow"
          "SUPER, mouse:273, resizewindow"
        ];

        binde = [
          "SUPER, left , movefocus, l"
          "SUPER, down , movefocus, d"
          "SUPER, up   , movefocus, u"
          "SUPER, right, movefocus, r"

          "SUPER, h, movefocus, l"
          "SUPER, j, movefocus, d"
          "SUPER, k, movefocus, u"
          "SUPER, l, movefocus, r"

          "SUPER+CTRL, left , resizeactive, -100 0"
          "SUPER+CTRL, down , resizeactive, 0 100"
          "SUPER+CTRL, up   , resizeactive, 0 -100"
          "SUPER+CTRL, right, resizeactive, 100 0"

          "SUPER+CTRL, h, resizeactive, -100 0"
          "SUPER+CTRL, j, resizeactive, 0 100"
          "SUPER+CTRL, k, resizeactive, 0 -100"
          "SUPER+CTRL, l, resizeactive, 100 0"
        ];

        bind = flatten [
          "SUPER      , TAB, workspace, e+1"
          "SUPER+SHIFT, TAB, workspace, e-1"

          "SUPER, mouse_up,   workspace, e+1"
          "SUPER, mouse_down, workspace, e-1"

          (map (n: [
            "SUPER      , ${toString n}, workspace            , ${toString n}"
            "SUPER+SHIFT, ${toString n}, movetoworkspacesilent, ${toString n}"
          ]) <| range 1 9)
          "SUPER      , 0, workspace            , 10"
          "SUPER+SHIFT, 0, movetoworkspacesilent, 10"

          "SUPER+SHIFT, left , movewindow, l"
          "SUPER+SHIFT, down , movewindow, d"
          "SUPER+SHIFT, up   , movewindow, u"
          "SUPER+SHIFT, right, movewindow, r"

          "SUPER+SHIFT, h, movewindow, l"
          "SUPER+SHIFT, j, movewindow, d"
          "SUPER+SHIFT, k, movewindow, u"
          "SUPER+SHIFT, l, movewindow, r"

          "SUPER      , Q, killactive"
          "SUPER      , F, fullscreen"
          "SUPER+SHIFT, F, togglefloating"

          "SUPER+SHIFT, RETURN, exec, kitty"
          "SUPER      , RETURN, exec, ghostty --gtk-single-instance=true"
          "SUPER      , W     , exec, zen-beta"
          "SUPER      , D     , exec, discord"
          "SUPER      , Z     , exec, zulip"
          "SUPER      , M     , exec, thunderbird"
          "SUPER      , T     , exec, thunar"
          "SUPER      , C     , exec, hyprpicker --autocopy"

          "     , PRINT, exec, pkill grim; grim -g \"$(slurp -w 0)\" - | swappy -f - -o - | wl-copy --type image/png"
          "SHIFT, PRINT, exec, pkill grim; grim                      - | swappy -f - -o - | wl-copy --type image/png"
        ];

        general = with config.theme; {
          gaps_in     = margin / 2;
          gaps_out    = margin;
          border_size = borderWidth;

          "col.active_border"         = "0xFF${base0A}";
          "col.nogroup_border_active" = "0xFF${base0A}";

          "col.inactive_border" = "0xFF${base01}";
          "col.nogroup_border"  = "0xFF${base01}";

          resize_on_border = true;
        };

        decoration = {
          drop_shadow = false;
          rounding    = config.theme.cornerRadius;

          blur.enabled = false;
        };

        input = {
          follow_mouse = 1;

          kb_layout = "tr-swapped-i";

          repeat_delay = 400;
          repeat_rate  = 100;

          touchpad = {
            clickfinger_behavior = true;
            drag_lock            = true;

            natural_scroll = true;
            scroll_factor  = 0.7;
          };
        };

        gestures.workspace_swipe = true;

        animations = {
          bezier = [ "material_decelerate, 0.05, 0.7, 0.1, 1" ];

          animation = [
            "border    , 1, 2, material_decelerate"
            "fade      , 1, 2, material_decelerate"
            "layers    , 1, 2, material_decelerate"
            "windows   , 1, 2, material_decelerate, popin 80%"
            "workspaces, 1, 2, material_decelerate"
          ];
        };

        misc = {
          animate_manual_resizes = true;

          background_color         = config.theme.with0x.base00;
          disable_hyprland_logo    = true;
          disable_splash_rendering = true;

          key_press_enables_dpms   = true;
          mouse_move_enables_dpms  = true;
        };

        cursor = {
          hide_on_key_press = true;
          inactive_timeout  = 10;
          no_warps          = true;
        };

        dwindle = {
          preserve_split = true;
          smart_resizing = false;
        };

        debug.error_position = 1;
      };
    };
  }];
}
