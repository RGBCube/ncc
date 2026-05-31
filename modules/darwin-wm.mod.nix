{ self, ... }:
{
  flake.darwinModules.darwin-wm = {
    # NSGLOBALDOMAIN
    system.defaults.NSGlobalDomain = {
      _HIHideMenuBar = false; # Only hide menubar on fullscreen.

      AppleScrollerPagingBehavior = true; # Jump to the spot that was pressed in the scrollbar.
      AppleShowScrollBars = "WhenScrolling";

      NSWindowShouldDragOnGesture = true; # CMD+CTRL click to drag window.
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
    system.defaults.CustomSystemPreferences."com.apple.dock".workspaces-auto-swoosh = false;

    # KEYBOARD BACKLIGHT
    system.defaults.CustomSystemPreferences."com.apple.CoreBrightness" = {
      "Keyboard Dim Time" = 60;
      KeyboardBacklight.KeyboardBacklightIdleDimTime = 60;
    };

    # TRACKPAD
    system.defaults.CustomSystemPreferences."com.apple.AppleMultitouchTrackpad" = {
      TrackpadThreeFingerVertSwipeGesture = 0; # Four finger swipe up for mission control.

      # Disable 3 finger horizontal stuff.
      TrackpadFourFingerHorizSwipeGesture = 0;
      TrackpadThreeFingerHorizSwipeGesture = 0;

      # Smooth clicking.
      FirstClickThreshold = 0;
      SecondClickThreshold = 0;
    };

    # ACCESSIBILITY
    system.defaults.CustomSystemPreferences."com.apple.Accessibility".ReduceMotionEnabled = 1;
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
          rev = "88aa02ad9002d1b5697aeaf9fb27cdb5cedc4964";
          hash = "sha256-c6ltYZKLjZXXin8UaURY0xIrdFvA06aKxC5oty2FCdY=";
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

          local windowClose = function()
            local window = hs.window.focusedWindow()
            if not window then return end
            window:close()
          end

          local currentSpaceIndex = function()
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
          end

          local space_task = nil

          local changeSpaceBy = function(offset)
            if offset == 0 then return end

            if space_task and space_task:isRunning() then
              space_task:terminate()
            end

            space_task = hs.task.new("${
              getExe self.packages.${osConfig.nixpkgs.hostPlatform.system}.fast-workspace-switch
            }", nil, nil, {
              offset > 0 and "right" or "left",
              tostring(math.abs(offset)),
            })

            space_task:start()
          end

          local gotoSpace = function(index)
            local current_index = currentSpaceIndex()
            local change_by = index - current_index
            changeSpaceBy(change_by)
          end

          do -- HOTKEYS
            local super = { "cmd", "ctrl" }
            local super_alt = { "cmd", "ctrl", "alt" }
            local super_shift = { "cmd", "ctrl", "shift" }

            -- FOCUS
            hs.hotkey.bind(super, "left", function()
              PaperWM.actions.focus_left()
              PaperWM.actions.center_window()
            end)
            hs.hotkey.bind(super, "down", PaperWM.actions.focus_down)
            hs.hotkey.bind(super, "up", PaperWM.actions.focus_up)
            hs.hotkey.bind(super, "right", function()
              PaperWM.actions.focus_right()
              PaperWM.actions.center_window()
            end)

            -- RESIZE
            hs.hotkey.bind(super_alt, "left", function() windowResize(-100, 0) end)
            hs.hotkey.bind(super_alt, "down", function() windowResize(0, 100) end)
            hs.hotkey.bind(super_alt, "up", function() windowResize(0, -100) end)
            hs.hotkey.bind(super_alt, "right", function() windowResize(100, 0) end)

            hs.hotkey.bind(super_alt, "f", PaperWM.actions.full_width)

            -- SPACES
            hs.hotkey.bind(super, "tab", function() changeSpaceBy(1) end)
            hs.hotkey.bind(super_shift, "tab", function() changeSpaceBy(-1) end)

            for index = 1, 9 do
              hs.hotkey.bind(super, tostring(index), function() gotoSpace(index) end)
              hs.hotkey.bind(super_shift, tostring(index), PaperWM.actions["move_window_" .. index])
            end

            -- SWAP
            hs.hotkey.bind(super_shift, "left", PaperWM.actions.swap_left)
            hs.hotkey.bind(super_shift, "down", PaperWM.actions.swap_down)
            hs.hotkey.bind(super_shift, "up", PaperWM.actions.swap_up)
            hs.hotkey.bind(super_shift, "right", PaperWM.actions.swap_right)

            -- SLURP & BARF
            hs.hotkey.bind(super_shift, "t", PaperWM.actions.slurp_in)
            hs.hotkey.bind(super_shift, "g", PaperWM.actions.barf_out)

            -- MISC
            hs.hotkey.bind(super, "q", windowClose)
            hs.hotkey.bind(super, "c", PaperWM.actions.center_window)
            hs.hotkey.bind(super, "f", PaperWM.actions.toggle_floating)

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
              for _, button in pairs(space_buttons) do
                button:delete()
              end
              space_buttons = {}

              local current_space = hs.spaces.activeSpaceOnScreen()
              local spaces = hs.spaces.allSpaces()[hs.screen.mainScreen():getUUID()]

              for index = #spaces, 1, -1 do
                local space = spaces[index]

                local title = tostring(index)

                local attributes = space == current_space and {
                  color = { red = 1 }
                } or {}

                local button = hs.menubar.new()
                button:setTitle(hs.styledtext.new(title, attributes))
                button:setClickCallback(function()
                  gotoSpace(index)
                end)

                table.insert(space_buttons, button)
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
