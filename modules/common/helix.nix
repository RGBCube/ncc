{ config, lib, pkgs, ... }: let
  inherit (lib) attrValues const elem enabled genAttrs mapAttrs mkAfter mkIf optionalAttrs;
in {
  environment = {
    variables.EDITOR = "hx";
    shellAliases.x   = "hx";
  };

  # nixpkgs.overlays = [(self: super: {
  #   helix = super.helix.overrideAttrs (old: {
  #     src = self.fetchzip {
  #       url = "https://github.com/cull-os/helix/releases/download/ci-release-25.01.1/helix-ci-release-25.01.1-source.tar.xz";
  #       hash = "sha256-bvlzXRAdPvz8P49KENSw9gupQNaUm/+3eZZ1q7+fTsw=";
  #       stripRoot = false;
  #     };

  #     cargoDeps = self.rustPlatform.fetchCargoVendor {
  #       inherit (self.helix) src;
  #       hash = "sha256-soOnSRvWO7OzxYENFUBGmgSAk1Oy9Av+wDDLKkcuIbs=";
  #     };
  #   });
  # })];

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
      languages.language = let
        formattedLanguages = {
          astro      = "astro";
          css        = "css";
          html       = "html";
          javascript = "js";
          json       = "json";
          jsonc      = "jsonc";
          jsx        = "jsx";
          markdown   = "md";
          scss       = "scss";
          svelte     = "svelte";
          tsx        = "tsx";
          typescript = "ts";
          vue        = "vue";
          yaml       = "yaml";
        } |> mapAttrs (name: extension: {
            inherit name;

            auto-format       = true;
            formatter.command = "deno";
            formatter.args    = [ "fmt" "--unstable-component" "--ext" extension "-" ];
          } // optionalAttrs (elem name [ "javascript" "jsx" "typescript" "tsx" ]) {
            language-servers = [ "deno" ];
          })
          |> attrValues;
      in formattedLanguages ++ [
        {
          name              = "nix";
          auto-format       = false;
          formatter.command = "nixfmt";
        }

        {
          name             = "python";
          auto-format      = true;
          language-servers = [ "basedpyright" ];
        }

        {
          name = "rust";

          debugger.name      = "lldb-dap";
          debugger.transport = "stdio";
          debugger.command   = "lldb-dap";

          debugger.templates = [{
            name    = "binary";
            request = "launch";

            completion = [{
              name = "binary";
              completion = "filename";
            }];

            args.program      = "{0}";
            args.initCommands = let
              primer = pkgs.runCommand "primer" {} (/* py */ ''
                mkdir $out
                echo '

                import subprocess
                import pathlib
                import lldb

                # Not hardcoding a nix store path here on purpose.
                rustlib_etc = pathlib.Path(subprocess.getoutput("rustc --print sysroot")) / "lib" / "rustlib" / "etc"
                if not rustlib_etc.exists():
                    raise RuntimeError("Unable to determine rustc sysroot")

                # Load lldb_lookup.py and execute lldb_commands with the correct path
                lldb.debugger.HandleCommand(f"""command script import "{rustlib_etc / 'lldb_lookup.py'}" """)
                lldb.debugger.HandleCommand(f"""command source -s 0 "{rustlib_etc / 'lldb_commands'}" """)

                ' > $out/primer.py
              '');
            in [ "command script import ${primer}/primer.py" ];
          }];
        }
      ];

      languages.language-server.deno = {
        command = "deno";
        args    = [ "lsp" ];

        environment.NO_COLOR = "1";

        config.javascript = enabled {
          lint     = true;
          unstable = true;

          suggest.imports.hosts."https://deno.land" = true;

          inlayHints = {
            enumMemberValues.enabled         = true;
            functionLikeReturnTypes.enabled  = true;
            parameterNames.enabled           = "all";
            parameterTypes.enabled           = true;
            propertyDeclarationTypes.enabled = true;
            variableTypes.enabled            = true;
          };
        };
      };

      languages.language-server.rust-analyzer = {
        config = {
          cargo.features               = "all";
          check.command                = "clippy";
          completion.callable.snippets = "add_parentheses";
          completion.excludeTraits     = [ "yansi::Paint" ];
          diagnostics.disabled         = [ "inactive-code" "unlinked-file" ];
        };
      };

      settings.theme = "gruvbox_dark_hard";

      settings.editor = {
        auto-completion    = false;
        bufferline         = "multiple";
        color-modes        = true;
        cursorline         = true;
        file-picker.hidden = false;
        idle-timeout       = 0;
        line-number        = "relative";
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

  environment.systemPackages = mkIf config.isDesktop <| attrValues {
    inherit (pkgs)
      # CMAKE
      cmake-language-server

      # GO
      gopls

      # HTML
      vscode-langservers-extracted

      # KOTLIN
      kotlin-language-server

      # LATEX
      texlab

      # LUA
      lua-language-server

      # MARKDOWN
      markdown-oxide

      # NIX
      nixfmt-rfc-style
      nil

      # PYTHON
      basedpyright

      # RUST
      rust-analyzer-nightly
      lldb

      # TYPESCRIPT & OTHERS
      deno

      # YAML
      yaml-language-server

      # ZIG
      zls
    ;
  };
}
