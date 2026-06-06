{
  flake.homeModules.commandline-copy =
    { pkgs, ... }:
    {
      programs.nushell.extraConfig = "source ${
        pkgs.writeText "commandline-copy.nu" /* nu */ ''
          use std/clip

          # `nu-highlight` with default colors
          #
          # Custom themes can produce a lot more ansi color codes and make the output
          # exceed discord's character limits
          def nu-highlight-default [] {
            let input = $in
            $env.config.color_config = {}
            $input | nu-highlight
          }

          # Copy the current commandline, add syntax highlighting, wrap it in a
          # markdown code block, copy that to the system clipboard.
          #
          # Perfect for sharing code snippets on Discord.
          def "nu-keybind commandline-copy" []: nothing -> nothing {
            commandline
            | nu-highlight-default
            | [
              "```ansi"
              $in
              "```"
            ]
            | str join (char nl)
            | clip copy --ansi
          }

          $env.config.keybindings ++= [
            {
              name: copy_color_commandline
              modifier: control_alt
              keycode: char_c
              mode: [ emacs vi_insert vi_normal ]
              event: {
                send: executehostcommand
                cmd: 'nu-keybind commandline-copy'
              }
            }
          ]
        ''
      }\n";
    };
}
