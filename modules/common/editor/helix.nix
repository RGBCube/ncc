{ config, lib, pkgs, ... }: let
  inherit (lib) const enabled genAttrs mkAfter mkIf;

  # CullOS Helix with Cab support:
  _package_cab = pkgs.helix.overrideAttrs (old: {
    src = pkgs.fetchzip {
      url = "https://github.com/cull-os/helix/releases/download/ci-release-25.01.1/helix-ci-release-25.01.1-source.tar.xz";
      hash = "sha256-bvlzXRAdPvz8P49KENSw9gupQNaUm/+3eZZ1q7+fTsw=";
      stripRoot = false;
    };

    cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
      inherit (pkgs.helix) src;
      hash = "sha256-soOnSRvWO7OzxYENFUBGmgSAk1Oy9Av+wDDLKkcuIbs=";
    };
  });

  _package = pkgs.helix.overrideAttrs (finalAttrs: _previousAttrs: {
    version = "25.07.2";
    src = pkgs.fetchzip {
      url = "https://github.com/bloxx12/helix/releases/download/${finalAttrs.version}/helix-${finalAttrs.version}-source.tar.xz";
      hash = "sha256-ZNsQwFfPXe6oewajx1tl68W60kVo7q2SuvTgy/o1HKk=";
      stripRoot = false;
    };

    doInstallCheck = false;

    cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
      inherit (pkgs.helix) src;
      hash = "sha256-JZwURUMUnwc3tzAsN7NJCE8106c/4VgZtHHA3e/BsXs=";
    };
  });

  package = pkgs.helix;
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
      inherit package;

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
