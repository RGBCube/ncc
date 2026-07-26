{ self, ... }:
{
  flake.homeModules.desktop = self.homeModules.ghostty;
  flake.homeModules.ghostty =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) mapAttrsToList optionalAttrs;
      inherit (lib.generators) mkKeyValueDefault toKeyValue;
      inherit (lib.modules) mkIf;
      inherit (lib.lists) singleton;
      inherit (lib.strings) concatLines;
    in
    {
      xdg.config.files."xdg-terminals.list" = mkIf osConfig.nixpkgs.hostPlatform.isLinux {
        generator = concatLines;
        value = singleton "com.mitchellh.ghostty.desktop";
      };

      packages = singleton (
        if osConfig.nixpkgs.hostPlatform.isDarwin then pkgs.ghostty-bin else pkgs.ghostty
      );

      xdg.config.files."ghostty/config".generator = toKeyValue {
        mkKeyValue = mkKeyValueDefault { } " = ";
        listsAsDuplicateKeys = true;
      };
      xdg.config.files."ghostty/config".value = {
        font-size = osConfig.theme.font.size.normal;
        font-family = osConfig.theme.font.mono.name;

        window-padding-x = osConfig.theme.padding;
        window-padding-y = osConfig.theme.padding;

        # 100 MiB
        scrollback-limit = 100 * 1024 * 1024;

        mouse-hide-while-typing = true;
        mouse-scroll-multiplier = "discrete:1";

        quit-after-last-window-closed = true;

        window-decoration = osConfig.nixpkgs.hostPlatform.isDarwin;

        config-file = "${pkgs.writeText "base16-config" osConfig.theme.ghosttyConfig}";

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

            t = "new_window";
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
      }
      // optionalAttrs osConfig.nixpkgs.hostPlatform.isDarwin {
        auto-update = "off";

        macos-titlebar-style = "tabs";
        macos-option-as-alt = "left";
      };
    };
}
