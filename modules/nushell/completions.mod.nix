{
  flake.homeModules.completions =
    { pkgs, lib, ... }:
    let
      inherit (lib.meta) getExe;
    in
    {
      packages = [
        pkgs.carapace
        pkgs.inshellisense
        pkgs.zsh
        pkgs.fish
        pkgs.bash
      ];

      environment.sessionVariables.CARAPACE_BRIDGES = "inshellisense,carapace,zsh,fish,bash";

      programs.nushell.extraConfig = "source ${
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
      }\n";
    };
}
