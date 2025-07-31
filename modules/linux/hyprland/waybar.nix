{ config, lib, ... }: let
  inherit (lib) enabled merge mkIf;
in merge <| mkIf config.isDesktop {
  home-manager.sharedModules = [{
    wayland.windowManager.hyprland.settings = {
      exec = [ "pkill --signal SIGUSR2 waybar" ];
      bind = [ "SUPER, B, exec, pkill --signal SIGUSR1 waybar" ];
    };

    programs.waybar = with config.theme.withHashtag; enabled {
      systemd = enabled;

      settings = [{
        layer  = "top";
        height = 2 * cornerRadius;

        margin-right = margin;
        margin-left  = margin;
        margin-top   = margin;

        modules-left = [ "hyprland/workspaces" ];

        "hyprland/workspaces" = {
          format               = "{icon}";
          format-icons.default = "";
          format-icons.active  = "";

          persistent-workspaces."*" = 10;
        };

        modules-center = [
          "hyprland/window"
        ];

        "hyprland/window" = {
          separate-outputs = true;

          rewrite."(.*) - Discord" = "󰙯 $1";
          rewrite."(.*) — Zen" = "󰖟 $1";
          rewrite."(.*) — nu"      = " $1";
        };

        modules-right = [ "tray" "pulseaudio" "backlight" "cpu" "memory" "network" "battery" "clock" ];

        tray = {
          reverse-direction = true;
          spacing           = 5;
        };

        pulseaudio = {
          format       = "{format_source} {icon} {volume}%";
          format-muted = "{format_source} 󰸈";

          format-bluetooth       = "{format_source} 󰋋 󰂯 {volume}%";
          format-bluetooth-muted = "{format_source} 󰟎 󰂯";

          format-source       = "󰍬";
          format-source-muted = "󰍭";

          format-icons.default = [ "󰕿" "󰖀" "󰕾" ];
        };

        backlight =  {
          format       = "{icon} {percent}%";
          format-icons = [ "" "" "" "" "" "" "" "" "" ];
        };

        cpu.format    = " {usage}%";
        memory.format = "󰽘 {}%";

        network = {
          format-disconnected = "󰤮 ";
          format-ethernet     = "󰈀 {ipaddr}/{cidr}";
          format-linked       = " {ifname} (No IP)";
          format-wifi         = " {signalStrength}%";
        };

        battery = {
          format          = "{icon} {capacity}%";
          format-charging = "󰂄 {capacity}%";
          format-plugged  = "󰂄 {capacity}%";

          format-icons = [ "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];

          states.warning  = 30;
          states.critical = 15;
        };

        clock.tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
      }];

      style = /* css */ ''
        * {
          border: none;
          border-radius: ${toString cornerRadius}px;
          font-family: "${font.sans.name}";
        }

        .modules-right {
          margin-right: ${toString padding}px;
        }

        #waybar {
          background: ${base00};
          color: ${base05};
        }

        #workspaces button:nth-child(1)  { color: ${base08}; }
        #workspaces button:nth-child(2)  { color: ${base09}; }
        #workspaces button:nth-child(3)  { color: ${base0A}; }
        #workspaces button:nth-child(4)  { color: ${base0B}; }
        #workspaces button:nth-child(5)  { color: ${base0C}; }
        #workspaces button:nth-child(6)  { color: ${base0D}; }
        #workspaces button:nth-child(7)  { color: ${base0E}; }
        #workspaces button:nth-child(8)  { color: ${base0F}; }
        #workspaces button:nth-child(9)  { color: ${base04}; }
        #workspaces button:nth-child(10) { color: ${base06}; }

        #workspaces button.empty {
          color: ${base02};
        }

        #tray, #pulseaudio, #backlight, #cpu, #memory, #network, #battery, #clock {
          margin-left: 20px;
        }

        @keyframes blink {
          to {
            color: ${base05};
          }
        }

        #battery.critical:not(.charging) {
          animation-direction: alternate;
          animation-duration: 0.5s;
          animation-iteration-count: infinite;
          animation-name: blink;
          animation-timing-function: linear;
          color: ${base08};
        }
      '';
    };
  }];
}
