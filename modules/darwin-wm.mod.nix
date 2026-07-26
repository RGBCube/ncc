{ self, ... }:
{
  flake.darwinModules.desktop = self.darwinModules.darwin-wm;
  flake.darwinModules.darwin-wm =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # NSGLOBALDOMAIN
      system.defaults.NSGlobalDomain = {
        _HIHideMenuBar = false; # Only hide menubar on fullscreen.

        AppleScrollerPagingBehavior = true; # Jump to the spot that was pressed in the scrollbar.
        AppleShowScrollBars = "WhenScrolling";

        NSWindowShouldDragOnGesture = true; # CMD+CTRL click to drag window. PaperWM intercepts this for tiled windows.
        AppleEnableMouseSwipeNavigateWithScrolls = false;
        AppleEnableSwipeNavigateWithScrolls = false;

        AppleWindowTabbingMode = "always"; # Always prefer tabs for new windows.
        AppleKeyboardUIMode = 3; # Full keyboard access.
        ApplePressAndHoldEnabled = false; # No ligatures when you press and hold a key, just repeat it.

        NSScrollAnimationEnabled = true;
        NSWindowResizeTime = 0.003;

        "com.apple.keyboard.fnState" = false; # Don't invert Fn.
        "com.apple.trackpad.scaling" = 1.5; # Faster tracking speed.

        # N * 15ms to start repeating, so about 150ms.
        InitialKeyRepeat = 10;
        # N * 15ms, so 15ms between each keypress (~66 per second).
        KeyRepeat = 1;

        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticInlinePredictionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;

        NSNavPanelExpandedStateForSaveMode = true; # Expand save panel by default.
        PMPrintingExpandedStateForPrint = true; # Expand print panel by default.

        AppleSpacesSwitchOnActivate = false; # Do not switch workspaces implicitly.
      };

      # DOCK
      system.defaults.CustomUserPreferences."com.apple.dock".workspaces-auto-swoosh = false;

      # KEYBOARD BACKLIGHT
      system.defaults.CustomUserPreferences."com.apple.CoreBrightness" = {
        "Keyboard Dim Time" = 60;
        KeyboardBacklight.KeyboardBacklightIdleDimTime = 60;
      };

      # HOTKEYS
      system.defaults.CustomUserPreferences."com.apple.symbolichotkeys".AppleSymbolicHotKeys =
        let
          inherit (lib.attrsets) getAttr mapAttrs;
          inherit (lib.fixedPoints) fix;
          inherit (lib.lists) foldl';
          inherit (lib.strings) charToInt;

          keyCodes =
            (
              {
                a = 0;
                b = 11;
                c = 8;
                d = 2;
                e = 14;
                f = 3;
                g = 5;
                h = 4;
                i = 34;
                j = 38;
                k = 40;
                l = 37;
                m = 46;
                n = 45;
                o = 31;
                p = 35;
                q = 12;
                r = 15;
                s = 1;
                t = 17;
                u = 32;
                v = 9;
                w = 13;
                x = 7;
                y = 16;
                z = 6;
              }
              |> mapAttrs (
                char: code: {
                  char = charToInt char;
                  inherit code;
                }
              )
            )
            // {
              space = {
                char = 32;
                code = 49;
              };
              tab = {
                char = 65535;
                code = 48;
              };
              backspace = {
                char = 65535;
                code = 51;
              };
            };

          hotkey = key: modifiers: {
            enabled = 1;

            value.type = "standard";
            value.parameters = [
              keyCodes.${key}.char
              keyCodes.${key}.code
              (
                modifiers
                |> foldl' (
                  total: modifier:
                  total
                  + getAttr modifier (
                    fix (self: {
                      shift = 131072;
                      control = 262144;
                      option = 524288;
                      command = 1048576;

                      super = self.command + self.control;
                    })
                  )
                ) 0
              )
            ];
          };
        in
        {
          # Save / Copy full screen.
          "28" = hotkey "s" [
            "super"
          ];
          "29" = hotkey "s" [
            "super"
            "option"
          ];

          # Save / Copy / Record Menu selected area.
          "30" = hotkey "a" [
            "super"
          ];
          "31" = hotkey "a" [
            "super"
            "option"
          ];
          "184" = hotkey "a" [
            "super"
            "shift"
          ];

          # Previous / Next input source.
          "60" = hotkey "tab" [
            "super"
            "option"
            "shift"
          ];
          "61" = hotkey "tab" [
            "super"
            "option"
          ];

          # Spotlight search launcher.
          "64" = hotkey "backspace" [
            "super"
          ];

          # Keyboard focus/navigation shortcuts: menu bar, Dock,
          # active/next window, window toolbar, floating window,
          # Full Keyboard Access toggle, Tab focus behavior, and app-window cycle.
          "7".enabled = 0;
          "8".enabled = 0;
          "9".enabled = 0;
          "10".enabled = 0;
          "11".enabled = 0;
          "12".enabled = 0;
          "13".enabled = 0;
          "27".enabled = 0;

          # Accessibility Zoom/display toggles: zoom, zoom in/out,
          # reverse black and white, and zoom image smoothing.
          "15".enabled = 0;
          "17".enabled = 0;
          "19".enabled = 0;
          "21".enabled = 0;
          "23".enabled = 0;

          # Increase / Decrease contrast.
          "25".enabled = 0;
          "26".enabled = 0;

          # Mission Control all-windows overview.
          "32" = hotkey "o" [
            "super"
          ];

          # Disable Application Windows and slow Mission Control variants.
          "33".enabled = 0;
          "34".enabled = 0;
          "35".enabled = 0;

          # Show desktop / slowly.
          "36".enabled = 0;
          "37".enabled = 0;

          # Toggle Dock hiding.
          "52".enabled = 0;

          # F14/F15 display brightness shortcuts, separate from hardware brightness keys.
          "53".enabled = 0;
          "54".enabled = 0;

          # Move focus to status menus.
          "57".enabled = 0;

          # VoiceOver.
          "59".enabled = 0;

          # Finder search window, which currently opens Spotlight on Tahoe.
          "65".enabled = 0;

          # Previous / Next space.
          "79".enabled = 0;
          "81".enabled = 0;

          # Previous / Next space, slow.
          "80".enabled = 0;
          "82".enabled = 0;

          # Help menu.
          "98".enabled = 0;

          # Trackpad handwriting.
          "156".enabled = 0;

          # Contextual menu.
          "159".enabled = 0;

          # Accessibility controls.
          "162".enabled = 0;

          # Hidden Control-alone hotkey from Apple's default template.
          "164".enabled = 0;

          # Save / Copy Touch Bar.
          "181".enabled = 0;
          "182".enabled = 0;

          # Quick Note.
          "190".enabled = 0;

          # Minimize window.
          "233".enabled = 0;

          # Fill / Center / Restore window.
          "237".enabled = 0;
          "238".enabled = 0;
          "239".enabled = 0;

          # Tile window to left / right / top / bottom half.
          "240".enabled = 0;
          "241".enabled = 0;
          "242".enabled = 0;
          "243".enabled = 0;

          # Arrange windows left/right, right/left, top/bottom, or bottom/top.
          "248".enabled = 0;
          "249".enabled = 0;
          "250".enabled = 0;
          "251".enabled = 0;
        };

      system.activationScripts.postActivation.text =
        let
          inherit (lib.attrsets) mapAttrsToList;
          inherit (lib.lists) map optionals;
          inherit (lib.meta) getExe;
          inherit (lib.strings) toJSON;

          reload-symbolic-hotkey = pkgs.callPackage (
            { stdenv, writeText }:
            stdenv.mkDerivation {
              pname = "reload-symbolic-hotkey";
              version = "1.0.0";

              src = writeText "reload-symbolic-hotkey.c" /* c */ ''
                #include <stdbool.h>
                #include <stdint.h>
                #include <stdio.h>
                #include <stdlib.h>

                typedef int32_t CGError;
                typedef int32_t CGSSymbolicHotKey;
                typedef uint16_t CGKeyCode;
                typedef uint32_t CGSModifierFlags;
                typedef uint16_t unichar;

                extern CGError CGSSetSymbolicHotKeyEnabled(CGSSymbolicHotKey hotKey, bool enabled);
                extern CGError CGSSetSymbolicHotKeyValue(
                    CGSSymbolicHotKey hotKey,
                    unichar keyEquivalent,
                    CGKeyCode virtualKeyCode,
                    CGSModifierFlags modifiers);

                static uint32_t parseUint32(const char *value) {
                  char *end = NULL;
                  unsigned long parsed = strtoul(value, &end, 10);

                  if (end == value || *end != '\0' || parsed > UINT32_MAX) {
                    fprintf(stderr, "invalid integer: %s\n", value);
                    exit(2);
                  }

                  return (uint32_t)parsed;
                }

                int main(int argc, char **argv) {
                  if (argc != 3 && argc != 6) {
                    fprintf(stderr, "usage: %s <id> <enabled> [char keycode modifiers]\n", argv[0]);
                    return 2;
                  }

                  CGSSymbolicHotKey id = (CGSSymbolicHotKey)parseUint32(argv[1]);
                  bool enabled = parseUint32(argv[2]) != 0;

                  CGError value_error = 0;
                  if (argc == 6) {
                    unichar key_equivalent = (unichar)parseUint32(argv[3]);
                    CGKeyCode virtual_key_code = (CGKeyCode)parseUint32(argv[4]);
                    CGSModifierFlags modifiers = (CGSModifierFlags)parseUint32(argv[5]);
                    value_error = CGSSetSymbolicHotKeyValue(id, key_equivalent, virtual_key_code, modifiers);
                  }

                  CGError enabled_error = CGSSetSymbolicHotKeyEnabled(id, enabled);

                  return value_error == 0 && enabled_error == 0 ? 0 : 1;
                }
              '';

              dontUnpack = true;
              dontConfigure = true;

              buildPhase = /* bash */ ''
                $CC -O2 -Wall -Wextra \
                  -framework CoreGraphics \
                  -o reload-symbolic-hotkey $src
              '';

              installPhase = /* bash */ ''
                mkdir -p $out/bin
                install -m755 reload-symbolic-hotkey $out/bin/
              '';

              meta.mainProgram = "reload-symbolic-hotkey";
            }
          ) { };
        in
        "${pkgs.writers.writeNu "reload-symbolic-hotkeys.nu" /* nu */ ''
          print "reloading symbolic hotkeys..."

          let user = r###'${config.system.primaryUser}'###
          let uid = sys users | where name == $user | get 0.id

          ^/bin/launchctl asuser $uid /usr/bin/sudo --set-home --user $user -- ${
            pkgs.writers.writeNu "reload-symbolic-hotkeys-peruser.nu" /* nu */ ''
              let hotkeys = r###'${
                config.system.defaults.CustomUserPreferences."com.apple.symbolichotkeys".AppleSymbolicHotKeys
                |> mapAttrsToList (
                  id:
                  {
                    enabled,
                    value ? null,
                  }:
                  [
                    id
                    (toString enabled)
                  ]
                  ++ optionals (value != null) (map toString value.parameters)
                )
                |> toJSON
              }'### | from json

              for hotkey in $hotkeys {
                ^${getExe reload-symbolic-hotkey} ...$hotkey
              }
            ''
          }
        ''}";

      # TRACKPAD
      system.defaults.CustomUserPreferences."com.apple.AppleMultitouchTrackpad" = {
        TrackpadThreeFingerVertSwipeGesture = 0; # Four finger swipe up for mission control.

        # Disable 3 finger horizontal stuff.
        TrackpadFourFingerHorizSwipeGesture = 0;
        TrackpadThreeFingerHorizSwipeGesture = 0;

        # Smooth clicking.
        FirstClickThreshold = 0;
        SecondClickThreshold = 0;
      };

      # ACCESSIBILITY
      system.defaults.CustomUserPreferences."com.apple.Accessibility".ReduceMotionEnabled = 1;
      system.defaults.universalaccess.reduceMotion = true;

      # WINDOW MANAGER
      system.defaults.WindowManager = {
        AppWindowGroupingBehavior = false; # Show them one at a time.
      };
    };

  flake.homeModules.darwin-wm =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkAfter mkIf;

      isDarwin = osConfig.nixpkgs.hostPlatform.isDarwin;
    in
    {
      # SPOONS
      xdg.config.files."hammerspoon/Spoons/PaperWM.spoon" = mkIf isDarwin {
        source = pkgs.fetchFromGitHub {
          owner = "mogenson";
          repo = "PaperWM.spoon";
          rev = "34787bf38ce429a84f94ae00a73418e32cc1abb8";
          hash = "sha256-hffz5Ae/INkYXRgZVX4FNejCbqC1l1aTigFRDFe8cYM=";
        };
      };

      xdg.config.files."hammerspoon/Spoons/Swipe.spoon" = mkIf isDarwin {
        source = pkgs.fetchFromGitHub {
          owner = "mogenson";
          repo = "Swipe.spoon";
          rev = "c56520507d98e663ae0e1228e41cac690557d4aa";
          hash = "sha256-G0kuCrG6lz4R+LdAqNWiMXneF09pLI+xKCiagryBb5k=";
        };
      };

      # INIT
      xdg.config.files."hammerspoon/init.lua" = mkIf isDarwin {
        text = mkAfter /* lua */ ''
          ---@type table
          _G.hs = _G.hs

          PaperWM = hs.loadSpoon("PaperWM")
          Swipe = hs.loadSpoon("Swipe")

          local space_task = nil

          local changeSpaceBy = function(offset)
            if offset == 0 then return end

            if space_task and space_task:isRunning() then
              space_task:terminate()
            end

            space_task = hs.task.new("${
              getExe self.packages.${osConfig.nixpkgs.hostPlatform.system}.fast-workspace-switch
            }", nil, {
              offset > 0 and "right" or "left",
              tostring(math.abs(offset)),
            })

            space_task:start()
          end

          local gotoSpace = function(index)
            local current_index = (function()
              local current_space = hs.spaces.activeSpaceOnScreen()
              local spaces = hs.spaces.allSpaces()[hs.screen.mainScreen():getUUID()]

              local current_index = nil
              for space_index, space in ipairs(spaces) do
                if space == current_space then
                  current_index = space_index
                  break
                end
              end

              return current_index
            end)()
            local change_by = index - current_index

            changeSpaceBy(change_by)
          end

          do -- HOTKEYS
            local super = { "cmd", "ctrl" }
            local super_alt = { "cmd", "ctrl", "alt" }
            local super_shift = { "cmd", "ctrl", "shift" }

            local actions = PaperWM.actions.actions()

            -- SPACES
            hs.hotkey.bind(super, "tab", function() changeSpaceBy(1) end)
            hs.hotkey.bind(super_shift, "tab", function() changeSpaceBy(-1) end)

            for index = 1, 9 do
              hs.hotkey.bind(super, tostring(index), function() gotoSpace(index) end)
              hs.hotkey.bind(super_shift, tostring(index), actions["move_window_" .. index])
            end

            -- FOCUS
            PaperWM.drag_window = super
            hs.hotkey.bind(super, "left", function()
              actions.focus_left()
              actions.center_window()
            end)
            hs.hotkey.bind(super, "down", actions.focus_down)
            hs.hotkey.bind(super, "up", actions.focus_up)
            hs.hotkey.bind(super, "right", function()
              actions.focus_right()
              actions.center_window()
            end)

            -- RESIZE
            do
              local windowResize = function(offsetWidth, offsetHeight)
                local window = hs.window.focusedWindow()
                if not window then return end

                local window_frame = window:frame()
                local screen_frame = window:screen():frame()

                window_frame.w = window_frame.w + offsetWidth
                window_frame.w = math.max(100, math.min(window_frame.w, screen_frame.w - window_frame.x))

                window_frame.h = window_frame.h + offsetHeight
                window_frame.h = math.max(100, math.min(window_frame.h, screen_frame.h - window_frame.y))

                window:setFrame(window_frame)
              end

              hs.hotkey.bind(super_alt, "left", function() windowResize(-100, 0) end)
              hs.hotkey.bind(super_alt, "down", function() windowResize(0, 100) end)
              hs.hotkey.bind(super_alt, "up", function() windowResize(0, -100) end)
              hs.hotkey.bind(super_alt, "right", function() windowResize(100, 0) end)
            end

            hs.hotkey.bind(super_alt, "f", actions.full_width)

            -- SWAP
            PaperWM.lift_window = super_shift
            hs.hotkey.bind(super_shift, "left", actions.swap_left)
            hs.hotkey.bind(super_shift, "down", actions.swap_down)
            hs.hotkey.bind(super_shift, "up", actions.swap_up)
            hs.hotkey.bind(super_shift, "right", actions.swap_right)

            -- SLURP & BARF
            hs.hotkey.bind(super_shift, "t", actions.slurp_in)
            hs.hotkey.bind(super_shift, "g", actions.barf_out)

            -- MISC
            hs.hotkey.bind(super, "q", function()
              local window = hs.window.focusedWindow()
              if not window then return end
              window:close()
            end)
            hs.hotkey.bind(super, "c", actions.center_window)
            hs.hotkey.bind(super, "f", actions.toggle_floating)

            -- APPLICATIONS
            hs.hotkey.bind(super, "w", function() hs.application.launchOrFocus("Helium") end)
            hs.hotkey.bind(super, "return", function()
              local ghostty = hs.application.get("Ghostty")

              if not ghostty then
                hs.application.launchOrFocus("Ghostty")
                return
              end

              ghostty:activate()
              hs.eventtap.keyStroke({ "ctrl", "shift" }, "t", 0, ghostty)
            end)
            hs.hotkey.bind(super, "t", function() hs.application.launchOrFocus("Finder") end)

            PaperWM.swipe_fingers = 3
            PaperWM.swipe_gain = 1.7

            PaperWM:start()
          end

          do -- 3 FINGER VERTICAL SWIPE TO CHANGE SPACES
            local current_id, threshold

            Swipe:start(3, function(direction, distance, id)
              if id ~= current_id then
                current_id = id
                threshold = 0.2
                return
              end

              if distance > threshold then
                threshold = math.huge

                if direction == "up" then
                  changeSpaceBy(1)
                elseif direction == "down" then
                  changeSpaceBy(-1)
                end
              end
            end)
          end

          do -- SPACE BUTTONS
            local space_buttons = {}

            local updateSpaceButtons = function()
              local current_space = hs.spaces.activeSpaceOnScreen()
              local spaces = hs.spaces.allSpaces()[hs.screen.mainScreen():getUUID()]

              if #space_buttons ~= #spaces then
                for _, button in pairs(space_buttons) do
                  button:delete()
                end
                space_buttons = {}

                for index = #spaces, 1, -1 do
                  space_buttons[index] = hs.menubar.new()

                  space_buttons[index]:setClickCallback(function()
                    gotoSpace(index)
                  end)
                end
              end

              for index, space in ipairs(spaces) do
                local attributes = space == current_space and {
                  color = { red = 1 }
                } or {}

                space_buttons[index]:setTitle(hs.styledtext.new(tostring(index), attributes))
              end
            end

            hs.spaces.watcher.new(updateSpaceButtons):start()

            updateSpaceButtons()
          end

          do -- NO ANIMATIONS
            hs.window.animationDuration = 0
          end
        '';
      };
    };
}
