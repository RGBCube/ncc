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
  
        # 100 MiB
        scrollback-limit = 100 * 1024 * 1024;

        mouse-hide-while-typing = true;

        confirm-close-surface         = false;
        quit-after-last-window-closed = true;

        window-decoration    = config.isDarwin;
        macos-titlebar-style = "tabs";

        macos-option-as-alt = "left";

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

          "one"   = "goto_tab:1";
          "two"   = "goto_tab:2";
          "three" = "goto_tab:3";
          "four"  = "goto_tab:4";
          "five"  = "goto_tab:5";
          "six"   = "goto_tab:6";
          "seven" = "goto_tab:7";
          "eight" = "goto_tab:8";
          "nine"  = "goto_tab:9";
          "zero"  = "goto_tab:10";
        } ++ mapAttrsToList (name: value: "ctrl+${name}=${value}") {
          "tab"       = "next_tab";
          "shift+tab" = "previous_tab";
        };
      };
    };
  }];
}
