{
  flake.homeModules.helix =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets)
        attrValues
        genAttrs
        mapAttrs
        optionalAttrs
        ;
      inherit (lib.lists) elem;
      inherit (lib.modules) mkIf;
      inherit (lib.meta) getExe;
      inherit (lib.trivial) const flip;

      package = pkgs.helix;
    in
    {
      environment.sessionVariables.EDITOR = getExe package;

      xdg.mime-apps.default-applications =
        mkIf osConfig.nixpkgs.hostPlatform.isLinux
        <| flip genAttrs (const "Helix.desktop") [
          "application/x-shellscript"
          "text/english"
          "text/plain"
          "text/x-c"
          "text/x-c++"
          "text/x-c++hdr"
          "text/x-c++src"
          "text/x-chdr"
          "text/x-csrc"
          "text/x-java"
          "text/x-makefile"
          "text/x-moc"
          "text/x-pascal"
          "text/x-tcl"
          "text/x-tex"
        ];

      packages = [
        package
      ];
      xdg.config.files."helix/config.toml".generator = pkgs.writers.writeTOML "helix-config.toml";
      xdg.config.files."helix/config.toml".value = {
        theme = "gruvbox_dark_hard";

        editor = {
          auto-completion = false;
          bufferline = "multiple";
          color-modes = true;
          cursorline = true;
          file-picker.hidden = false;
          idle-timeout = 0;
          shell = [
            "nu"
            "--commands"
          ];
          text-width = 100;
        };

        editor.cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };

        editor.statusline.mode = {
          insert = "INSERT";
          normal = "NORMAL";
          select = "SELECT";
        };

        editor.indent-guides = {
          character = "▏";
          render = true;
        };

        editor.whitespace = {
          characters.tab = "→";
          render.tab = "all";
        };

        keys =
          genAttrs [
            "normal"
            "select"
          ]
          <| const {
            D = "extend_to_line_end";
          };
      };

      xdg.config.files."helix/languages.toml".generator = pkgs.writers.writeTOML "helix-languages.toml";
      xdg.config.files."helix/languages.toml".value = {
        language-server.deno = {
          command = "deno";
          args = [ "lsp" ];

          environment.NO_COLOR = "1";

          config.javascript = {
            enable = true;
            lint = true;
            unstable = true;

            suggest.imports.hosts."https://deno.land" = true;

            inlayHints.enumMemberValues.enabled = true;
            inlayHints.functionLikeReturnTypes.enabled = true;
            inlayHints.parameterNames.enabled = "all";
            inlayHints.parameterTypes.enabled = true;
            inlayHints.propertyDeclarationTypes.enabled = true;
            inlayHints.variableTypes.enabled = true;
          };
        };

        language-server.rust-analyzer = {
          config = {
            cargo.features = "all";
            check.command = "clippy";
            completion.callable.snippets = "add_parentheses";
            completion.excludeTraits = [ "yansi::Paint" ];
            diagnostics.disabled = [
              "inactive-code"
              "unlinked-file"
            ];
          };
        };

        language =
          (
            {
              astro = "astro";
              css = "css";
              html = "html";
              javascript = "js";
              json = "json";
              jsonc = "jsonc";
              jsx = "jsx";
              markdown = "md";
              scss = "scss";
              svelte = "svelte";
              tsx = "tsx";
              typescript = "ts";
              vue = "vue";
              yaml = "yaml";
            }
            |> mapAttrs (
              name: extension:
              {
                inherit name;

                auto-format = true;
                formatter.command = "deno";
                formatter.args = [
                  "fmt"
                  "--unstable-component"
                  "--ext"
                  extension
                  "-"
                ];
              }
              //
                optionalAttrs
                  (elem name [
                    "javascript"
                    "jsx"
                    "typescript"
                    "tsx"
                  ])
                  {
                    language-servers = [ "deno" ];
                  }
            )
            |> attrValues
          )
          ++ [
            {
              name = "nix";
              auto-format = true;
              formatter.command = "nixfmt";
            }

            {
              name = "python";
              auto-format = true;
              language-servers = [ "basedpyright" ];
            }

            {
              name = "toml";
              auto-format = true;
            }

            {
              name = "rust";

              debugger.name = "lldb-dap";
              debugger.transport = "stdio";
              debugger.command = "lldb-dap";

              debugger.templates = [
                {
                  name = "binary";
                  request = "launch";

                  completion = [
                    {
                      name = "binary";
                      completion = "filename";
                    }
                  ];

                  args.program = "{0}";
                  args.initCommands =
                    let
                      primer = pkgs.writeText "primer.py" ''
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
                      '';
                    in
                    [ "command script import ${primer}/primer.py" ];
                }
              ];
            }
          ];
      };
    };

  flake.homeModules.helix-desktop =
    { pkgs, ... }:
    {
      packages = [
        # CMAKE
        pkgs.cmake-language-server

        # GO
        pkgs.gopls

        # HTML
        pkgs.vscode-langservers-extracted

        # KOTLIN
        pkgs.kotlin-language-server

        # LATEX
        pkgs.texlab

        # LUA
        pkgs.lua-language-server

        # MARKDOWN
        pkgs.markdown-oxide

        # NIX
        pkgs.nixfmt
        pkgs.nil

        # PYTHON
        pkgs.basedpyright

        # RUST
        pkgs.rust-analyzer
        pkgs.lldb

        # TYPESCRIPT & OTHERS
        pkgs.deno

        # YAML
        pkgs.yaml-language-server
      ];
    };
}
