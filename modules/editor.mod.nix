{ self, ... }:
{
  flake.homeModules.shell = self.homeModules.helix;
  flake.homeModules.helix =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets)
        mapAttrsToList
        genAttrs
        optionalAttrs
        ;
      inherit (lib.lists) singleton;
      inherit (lib.modules) mkIf;
      inherit (lib.meta) getExe;
      inherit (lib.attrsets) unionOfDisjoint;
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

        # CMAKE
        pkgs.cmake-language-server

        # GO
        pkgs.gopls

        # HTML
        pkgs.vscode-langservers-extracted

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
        pkgs.ty
        pkgs.ruff

        # RUST
        pkgs.rust-analyzer
        pkgs.lldb

        # TYPESCRIPT & OTHERS
        pkgs.deno

        # YAML
        pkgs.yaml-language-server
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

        editor.indent-guides = {
          character = "▏";
          render = true;
        };

        editor.whitespace = {
          characters.tab = "→";
          render.tab = "all";
        };

        keys.normal.D = "extend_to_line_end";
        keys.select.D = "extend_to_line_end";
      };

      xdg.config.files."helix/languages.toml".generator =
        value:
        value
        // optionalAttrs (value ? language) {
          language = value.language |> mapAttrsToList (name: unionOfDisjoint { inherit name; });
        }
        |> pkgs.writers.writeTOML "helix-languages.toml";
      xdg.config.files."helix/languages.toml".value =
        let
          denoFor =
            extension:
            {
              language-server ? false,
            }:
            {
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
            // optionalAttrs language-server {
              language-servers = singleton "deno";
            };
        in
        {
          language-server.deno = {
            command = "deno";
            args = singleton "lsp";

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

          language.astro = denoFor "astro" { };
          language.css = denoFor "css" { };
          language.html = denoFor "html" { };
          language.javascript = denoFor "js" { language-server = true; };
          language.json = denoFor "json" { };
          language.jsonc = denoFor "jsonc" { };
          language.jsx = denoFor "jsx" { language-server = true; };
          language.markdown = denoFor "md" { };
          language.scss = denoFor "scss" { };
          language.svelte = denoFor "svelte" { };
          language.tsx = denoFor "tsx" { language-server = true; };
          language.typescript = denoFor "ts" { language-server = true; };
          language.vue = denoFor "vue" { };
          language.yaml = denoFor "yaml" { };

          language.nix = {
            auto-format = true;
            formatter.command = "nixfmt";
          };

          language.python = {
            auto-format = true;
            language-servers = [
              "ty"
              "ruff"
            ];
          };

          language.toml.auto-format = true;
        };
    };
}
