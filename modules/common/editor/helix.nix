{ config, lib, ... }: let
  inherit (lib) const enabled genAttrs mkAfter mkIf;
in {
  editor.defaultAlias = "hx";

  home-manager.sharedModules = [{
    programs.nushell.configFile.text = mkIf /*(*/config.isDesktop/* && config.isLinux)*/ <| mkAfter /* nu */ ''
      def --wrapped hx [...arguments] {
        if $env.TERM == "xterm-kitty" {
          kitty @ set-spacing padding=0
        }

        RUST_BACKTRACE=full ^hx ...($arguments | each { glob $in } | flatten)

        if $env.TERM == "xterm-kitty" {
          kitty @ set-spacing padding=${toString config.theme.padding}
        }
      }
    '';

    programs.helix = enabled {
      languages.language        = config.editor.languageConfigsHelix;
      languages.language-server = config.editor.lspConfigsHelix;

      settings.theme = "gruvbox_dark_hard";

      settings.editor = {
        auto-completion    = false;
        bufferline         = "multiple";
        color-modes        = true;
        cursorline         = true;
        file-picker.hidden = false;
        idle-timeout       = 0;
        shell              = [ "nu" "--commands" ];
        text-width         = 100;
      };

      settings.editor.cursor-shape = {
        insert = "bar";
        normal = "block";
        select = "underline";
      };

      settings.editor.statusline.mode = {
        insert = "INSERT";
        normal = "NORMAL";
        select = "SELECT";
      };

      settings.editor.indent-guides = {
        character = "▏";
        render = true;
      };

      settings.editor.whitespace = {
        characters.tab = "→";
        render.tab     = "all";
      };

      settings.keys = genAttrs [ "normal" "select" ] <| const {
        D = "extend_to_line_end";
      };
    };
  }];
}
