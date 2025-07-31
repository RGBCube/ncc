{ config, lib, pkgs, ... }: let
  inherit (lib) mkAfter;
in {
  system.defaults.NSGlobalDomain = {
    _HIHideMenuBar = false; # Only hide menubar on fullscreen.

    AppleInterfaceStyle = if lib.isDark config.theme then "Dark" else null;

    AppleScrollerPagingBehavior = true; # Jump to the spot that was pressed in the scrollbar.
    AppleShowScrollBars         = "WhenScrolling";

    NSWindowShouldDragOnGesture              = true; # CMD+CTRL click to drag window.
    AppleEnableMouseSwipeNavigateWithScrolls = false;
    AppleEnableSwipeNavigateWithScrolls      = false;

    AppleWindowTabbingMode = "always"; # Always prefer tabs for new windows.
    AppleKeyboardUIMode      = 3;      # Full keyboard access.
    ApplePressAndHoldEnabled = false;  # No ligatures when you press and hold a key, just repeat it.

    NSScrollAnimationEnabled = true;
    NSWindowResizeTime       = 0.003;

    "com.apple.keyboard.fnState" = false; # Don't invert Fn.
    "com.apple.trackpad.scaling" = 1.5;   # Faster mouse speed.

    InitialKeyRepeat = 12;
    KeyRepeat        = 1;

    NSAutomaticCapitalizationEnabled     = false;
    NSAutomaticDashSubstitutionEnabled   = false;
    NSAutomaticInlinePredictionEnabled   = false;
    NSAutomaticPeriodSubstitutionEnabled = false;
    NSAutomaticQuoteSubstitutionEnabled  = false;

    NSNavPanelExpandedStateForSaveMode = true; # Expand save panel by default.
    PMPrintingExpandedStateForPrint = true;    # Expand print panel by default.

    AppleSpacesSwitchOnActivate = false; # Do not switch workspaces implicitly.
  };

  system.defaults.CustomSystemPreferences."com.apple.dock".workspaces-auto-swoosh = false; # Read `AppleSpacesSwitchOnActivate`.

  system.defaults.CustomSystemPreferences."com.apple.CoreBrightness" = {
    "Keyboard Dim Time" = 60;
    KeyboardBacklight.KeyboardBacklightIdleDimTime = 60;
  };

  system.defaults.CustomSystemPreferences."com.apple.AppleMultitouchTrackpad" = {
    TrackpadThreeFingerVertSwipeGesture = 0; # Four finger swipe up for mission control.

    # Disable 3 finger horizontal stuff.
    TrackpadFourFingerHorizSwipeGesture  = 0;
    TrackpadThreeFingerHorizSwipeGesture = 0;

    # Smooth clicking.
    FirstClickThreshold  = 0;
    SecondClickThreshold = 0;
  };

  system.defaults.CustomSystemPreferences."com.apple.Accessibility".ReduceMotionEnabled = 1;
  system.defaults.universalaccess.reduceMotion                                          = true;

  system.defaults.WindowManager = {
    AppWindowGroupingBehavior = false; # Show them one at a a time.
  };

  home-manager.sharedModules = [{
    xdg.configFile."hammerspoon/Spoons/PaperWM.spoon" = {
      recursive = true;

      source = pkgs.fetchFromGitHub {
        owner = "mogenson";
        repo  = "PaperWM.spoon";
        rev   = "88aa02ad9002d1b5697aeaf9fb27cdb5cedc4964";
        hash  = "sha256-c6ltYZKLjZXXin8UaURY0xIrdFvA06aKxC5oty2FCdY=";
      };
    };

    xdg.configFile."hammerspoon/Spoons/Swipe.spoon" = {
      recursive = true;

      source = pkgs.fetchFromGitHub {
        owner = "mogenson";
        repo  = "Swipe.spoon";
        rev   = "c56520507d98e663ae0e1228e41cac690557d4aa";
        hash  = "sha256-G0kuCrG6lz4R+LdAqNWiMXneF09pLI+xKCiagryBb5k=";
      };
    };

    xdg.configFile."hammerspoon/init.lua".text = mkAfter /* lua */ ''
      ---@type table
      _G.hs = _G.hs

      PaperWM = hs.loadSpoon("PaperWM")
      Swipe = hs.loadSpoon("Swipe")

      local windowResize = function(offsetWidth, offsetHeight)
        local window = hs.window.focusedWindow()
        if not window then return end

        local window_frame = window:frame()
        local screen_frame = window:screen():frame()

        -- Adjust width
        window_frame.w = window_frame.w + offsetWidth
        window_frame.w = math.max(100, math.min(window_frame.w, screen_frame.w - window_frame.x))

        -- Adjust height
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

      local changeSpaceBy = function(offset)
        local current_index = currentSpaceIndex()
        local spaces = hs.spaces.allSpaces()[hs.screen.mainScreen():getUUID()]

        local next_index = current_index + offset
        if next_index > #spaces then
          next_index = 1
        elseif next_index <= 0 then
          next_index = #spaces
        end

        if next_index == current_index then
          return
        end

        local next_space = spaces[next_index]

        hs.spaces.gotoSpace(next_space)
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

        -- FOCUS -- SUPER + DIRECTION
        hs.hotkey.bind(super, "left", PaperWM.actions.focus_left)
        hs.hotkey.bind(super, "down", PaperWM.actions.focus_down)
        hs.hotkey.bind(super, "up", PaperWM.actions.focus_up)
        hs.hotkey.bind(super, "right", PaperWM.actions.focus_right)

        hs.hotkey.bind(super, "h", PaperWM.actions.focus_left)
        hs.hotkey.bind(super, "j", PaperWM.actions.focus_down)
        hs.hotkey.bind(super, "k", PaperWM.actions.focus_up)
        hs.hotkey.bind(super, "l", PaperWM.actions.focus_right)

        -- RESIZE WINDOW -- SUPER + ALT + DIRECTION
        hs.hotkey.bind(super_alt, "left", function() windowResize(-100, 0) end)
        hs.hotkey.bind(super_alt, "down", function() windowResize(0, 100) end)
        hs.hotkey.bind(super_alt, "up", function() windowResize(0, -100) end)
        hs.hotkey.bind(super_alt, "right", function() windowResize(100, 0) end)

        hs.hotkey.bind(super_alt, "h", function() windowResize(-100, 0) end)
        hs.hotkey.bind(super_alt, "j", function() windowResize(0, 100) end)
        hs.hotkey.bind(super_alt, "k", function() windowResize(0, -100) end)
        hs.hotkey.bind(super_alt, "l", function() windowResize(100, 0) end)

        -- RESIZE WINDOW TO FULL WIDTH -- SUPER + ALT + F
        hs.hotkey.bind(super_alt, "f", PaperWM.actions.full_width)

        -- CYCLE SPACES -- SUPER[ + SHIFT FOR REVERSE] + TAB
        hs.hotkey.bind(super, "tab", function() changeSpaceBy(1) end)
        hs.hotkey.bind(super_shift, "tab", function() changeSpaceBy(-1) end)

        for index = 1, 9 do
          -- GO TO SPACE -- SUPER + NUMBER
          hs.hotkey.bind(super, tostring(index), function() gotoSpace(index) end)

          -- MOVE WINDOW TO SPACE -- SUPER + SHIFT + NUMBER
          hs.hotkey.bind(super_shift, tostring(index), PaperWM.actions["move_window_" .. index])
        end

        -- SWAP WINDOW -- SUPER + SHIFT + DIRECTION
        hs.hotkey.bind(super_shift, "left", PaperWM.actions.swap_left)
        hs.hotkey.bind(super_shift, "down", PaperWM.actions.swap_down)
        hs.hotkey.bind(super_shift, "up", PaperWM.actions.swap_up)
        hs.hotkey.bind(super_shift, "right", PaperWM.actions.swap_right)

        hs.hotkey.bind(super_shift, "h", PaperWM.actions.swap_left)
        hs.hotkey.bind(super_shift, "j", PaperWM.actions.swap_down)
        hs.hotkey.bind(super_shift, "k", PaperWM.actions.swap_up)
        hs.hotkey.bind(super_shift, "l", PaperWM.actions.swap_right)

        -- SLURP & BARF WINDOW -- SUPER + SHIFT + T/G
        hs.hotkey.bind(super_shift, "t", PaperWM.actions.slurp_in)
        hs.hotkey.bind(super_shift, "g", PaperWM.actions.barf_out)

        -- MISC CONTROL
        hs.hotkey.bind(super, "q", windowClose)
        hs.hotkey.bind(super, "c", PaperWM.actions.center_window)
        hs.hotkey.bind(super, "f", PaperWM.actions.toggle_floating)

        -- APPLICATIONS
        hs.hotkey.bind(super, "w", function() hs.application.launchOrFocus("Zen Browser (Beta)") end)
        hs.hotkey.bind(super, "return", function() hs.application.launchOrFocus("Ghostty") end)
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
            threshold = 0.2 -- 20% of trackpad
            return
          end

          if distance > threshold then
            threshold = math.huge -- only trigger once per swipe

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
    '';
  }];
}
