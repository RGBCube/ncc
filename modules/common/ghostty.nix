{ config, lib, pkgs, ... }: let
  inherit (lib) enabled mapAttrsToList merge mkIf;
in merge <| mkIf config.isDesktop {
  environment.variables = {
    TERMINAL     = mkIf config.isLinux "ghostty";
    TERM_PROGRAM = mkIf config.isDarwin "ghostty";
  };

  home-manager.sharedModules = [{
    programs.ghostty = enabled {
      # Don't actually install Ghostty if we are on Darwin.
      # For some reason it is marked as broken.
      package = mkIf config.isDarwin null;

      # Can't install things from null.
      installBatSyntax = !config.isDarwin;

      clearDefaultKeybinds = true;

      settings = with config.theme; {
        font-size   = font.size.normal;
        font-family = font.mono.name;

        window-padding-x = padding;
        window-padding-y = padding;

        scrollback-limit = 10000;

        mouse-hide-while-typing = true;

        confirm-close-surface         = false;
        quit-after-last-window-closed = true;

        window-decoration    = config.isDarwin;
        macos-titlebar-style = "tabs";

        config-file = toString <| pkgs.writeText "base16-config" ghosttyConfig;

        keybind = mapAttrsToList (name: value: "ctrl+shift+${name}=${value}") {
          c = "copy_to_clipboard";
          v = "paste_from_clipboard";

          z = "jump_to_prompt:-2";
          x = "jump_to_prompt:2";

          h = "write_scrollback_file:paste";
          i = "inspector:toggle";

          page_down = "scroll_page_fractional:0.33";
          down      = "scroll_page_lines:1";
          j         = "scroll_page_lines:1";

          page_up = "scroll_page_fractional:-0.33";
          up      = "scroll_page_lines:-1";
          k       = "scroll_page_lines:-1";

          home = "scroll_to_top";
          end  = "scroll_to_bottom";

          enter = "reset_font_size";
          plus  = "increase_font_size:1";
          minus = "decrease_font_size:1";

          t = "new_tab";
          q = "close_surface";

          "physical:one"   = "goto_tab:1";
          "physical:two"   = "goto_tab:2";
          "physical:three" = "goto_tab:3";
          "physical:four"  = "goto_tab:4";
          "physical:five"  = "goto_tab:5";
          "physical:six"   = "goto_tab:6";
          "physical:seven" = "goto_tab:7";
          "physical:eight" = "goto_tab:8";
          "physical:nine"  = "goto_tab:9";
          "physical:zero"  = "goto_tab:10";
        } ++ mapAttrsToList (name: value: "ctrl+${name}=${value}") {
          "physical:tab"       = "next_tab";
          "shift+physical:tab" = "previous_tab";
        };
      };
    };
  }];
}
