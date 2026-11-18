{ self, ... }:
{
  flake.homeModules.shell = self.homeModules.completions;
  flake.homeModules.completions =
    {
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib.meta) getExe getExe';
      inherit (lib.modules) mkAfter;

      inshellisense = pkgs.inshellisense.overrideAttrs (
        final: _: {
          src = pkgs.fetchFromGitHub {
            owner = "RGBCube";
            repo = "inshellisense";
            rev = "f228971f77937c47eb535782dc46031308986ccb";
            hash = "sha256-ExPWzXvtZ0YPII+yl9RGl/pvPCKBATiXyXXRe26WJ4Q=";
          };

          npmDeps = pkgs.fetchNpmDeps {
            inherit (final) src;
            hash = "sha256-Dr+DaND5+aZssHTc55Eo2Qg7O9k/3RUrUmfonFRpDZY=";
          };
        }
      );
    in
    {
      packages = [
        pkgs.carapace
        inshellisense
        pkgs.zsh
        pkgs.fish
        pkgs.bash
      ];

      environment.sessionVariables.CARAPACE_BRIDGES = "inshellisense,carapace,zsh,fish,bash";

      xdg.data.files.inshellisense.source =
        (data: "${data}/inshellisense")
        <| pkgs.stdenvNoCC.mkDerivation {
          name = "inshellisense-resources";
          args = [ ];
          realBuilder = pkgs.writers.writeNu "inshellisense-init.nu" /* nu */ ''
            $env.XDG_DATA_HOME = $env.out
            cd ${inshellisense}/lib/node_modules/@microsoft/inshellisense
            ^${getExe' inshellisense "is"} init nu | ignore
          '';
        };

      xdg.config.files."nushell/config.nu".text = mkAfter "source ${
        pkgs.writeText "completions.nu" /* nu */ ''
          let menus = [
            {
              name: completion_menu
              only_buffer_difference: false
              marker: $env.PROMPT_INDICATOR
              type: {
                layout: ide
                min_completion_width: 0
                max_completion_width: 150
                max_completion_height: 25
                padding: 0
                border: false
                cursor_offset: 0
                description_mode: "prefer_right"
                min_description_width: 0
                max_description_width: 50
                max_description_height: 10
                description_offset: 1
                correct_cursor_pos: true
              }
              style: {
                text: white
                selected_text: white_reverse
                description_text: yellow
                match_text: { attr: u }
                selected_match_text: { attr: ur }
              }
            }
            {
              name: history_menu
              only_buffer_difference: true
              marker: $env.PROMPT_INDICATOR
              type: {
                layout: list
                page_size: 10
              }
              style: {
                text: white
                selected_text: white_reverse
              }
            }
          ]

          $env.config.menus = $env.config.menus
          | where name not-in ($menus | get name)
          | append $menus

          source ${
            pkgs.runCommand "carapace.nu" { } /* bash */ ''
              ${getExe pkgs.carapace} _carapace nushell > $out
            ''
          }
        ''
      }";
    };
}
