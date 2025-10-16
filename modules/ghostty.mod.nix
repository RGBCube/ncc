{
  homeModules.ghostty =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) mapAttrsToList;
      inherit (lib.generators) toKeyValue;
      inherit (lib.modules) mkIf;
    in
    {
      environment.sessionVariables = {
        TERMINAL = mkIf config.nixpkgs.system.isLinux "ghostty";
        TERM_PROGRAM = mkIf config.nixpkgs.system.isDarwin "ghostty";
      };

      packages = mkIf config.nixpkgs.system.isLinux [
        pkgs.ghostty
      ];

      xdg.config.file."ghostty/config".generator = toKeyValue { };
      xdg.config.file."ghostty/config".value = {
        font-size = config.theme.font.size.normal;
        font-family = config.theme.font.mono.name;

        window-padding-x = config.theme.padding;
        window-padding-y = config.theme.padding;

        # 100 MiB
        scrollback-limit = 100 * 1024 * 1024;

        mouse-hide-while-typing = true;

        confirm-close-surface = false;
        quit-after-last-window-closed = true;

        window-decoration = config.nixpkgs.system.isDarwin;
        macos-titlebar-style = mkIf config.nixpkgs.system.isDarwin "tabs";

        macos-option-as-alt = mkIf config.nixpkgs.system.isDarwin "left";

        config-file = pkgs.writeText "base16-config" config.theme.ghosttyConfig;

        keybind =
          mapAttrsToList (name: value: "ctrl+shift+${name}=${value}") {
            c = "copy_to_clipboard";
            v = "paste_from_clipboard";

            z = "jump_to_prompt:-2";
            x = "jump_to_prompt:2";

            h = "write_scrollback_file:paste";
            i = "inspector:toggle";

            page_down = "scroll_page_fractional:0.33";
            down = "scroll_page_lines:1";
            j = "scroll_page_lines:1";

            page_up = "scroll_page_fractional:-0.33";
            up = "scroll_page_lines:-1";
            k = "scroll_page_lines:-1";

            home = "scroll_to_top";
            end = "scroll_to_bottom";

            enter = "reset_font_size";
            plus = "increase_font_size:1";
            minus = "decrease_font_size:1";

            t = "new_tab";
            q = "close_surface";

            "one" = "goto_tab:1";
            "two" = "goto_tab:2";
            "three" = "goto_tab:3";
            "four" = "goto_tab:4";
            "five" = "goto_tab:5";
            "six" = "goto_tab:6";
            "seven" = "goto_tab:7";
            "eight" = "goto_tab:8";
            "nine" = "goto_tab:9";
            "zero" = "goto_tab:10";
          }
          ++ mapAttrsToList (name: value: "ctrl+${name}=${value}") {
            "tab" = "next_tab";
            "shift+tab" = "previous_tab";
          };
      };
    };
}
