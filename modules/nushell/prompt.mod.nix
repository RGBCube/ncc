{ self, ... }:
{
  flake.homeModules.shell = self.homeModules.prompt;
  flake.homeModules.prompt =
    { pkgs, ... }:
    {
      xdg.config.files."nushell/config.nu".text = "source ${
        pkgs.writeText "prompt.nu" /* nu */ ''
          do --env {
            use std null_device

            def prompt-header [
              --left-char: string
              --right-char: string = "━"
            ]: nothing -> string {
              let code = $env.LAST_EXIT_CODE

              let segments = [
                # EXIT CODE
                (if $code != 0 { $"(ansi light_red_bold)($code)" })

                # COMMAND DURATION
                (($env.CMD_DURATION_MS | into int) * 1ms
                | if $in > 2sec { $"(ansi light_magenta_bold)($in)" })

                # NIX PACKAGES
                ($env.PATH
                | parse --regex "^/nix/store/[0-9a-z]{32}-(?<name>[^/]+?)(-[0-9][^/]*)?/bin/?$"
                | get name
                | each { str replace --regex "-(un)?wrapped$" "" }
                | uniq
                | reverse
                | str join " "
                | if ($in | is-not-empty) { $"(ansi light_blue_bold)($in)" })
              ]
              | compact
              | each {|segment| $"┫($segment)(ansi light_yellow_bold)┣" }
              | str join "━"
              | $"(ansi light_yellow_bold)($left_char)($in)($right_char)(ansi reset)"

              let body = [
                # HOSTNAME
                (if ($env.SSH_CONNECTION? | is-not-empty) { $"(ansi light_green_bold)@(sys host | get hostname)" })

                # DIRECTORY
                (do {
                  def relatify [ path: path ] {
                    if not ($path | str starts-with $env.HOME) { return $path }

                    "~" | path join ($path | path relative-to $env.HOME)
                  }

                  let pwd = relatify (pwd)
                  let jj_workspace_root = try { relatify (jj workspace root err> $null_device) | str trim --right --char "/" }

                  if ($jj_workspace_root | is-empty) or not ($pwd starts-with $jj_workspace_root) { return $"(ansi cyan)($pwd)" }

                  let subpath = $pwd | str substring ($jj_workspace_root | str length).. | str trim --left --char "/"

                  $"(ansi cyan)($jj_workspace_root)(ansi cyan_bold)(ansi attr_underline)/($subpath)"
                })
              ]
              | compact
              | str join " "
              | $" ($in)(ansi reset)"

              $"($segments)($body)(char newline)"
            }

            $env.PROMPT_INDICATOR = $"(ansi light_yellow_bold)┃(ansi reset) "
            $env.PROMPT_INDICATOR_VI_NORMAL = $env.PROMPT_INDICATOR
            $env.PROMPT_INDICATOR_VI_INSERT = $env.PROMPT_INDICATOR
            $env.PROMPT_MULTILINE_INDICATOR = $env.PROMPT_INDICATOR
            $env.PROMPT_COMMAND = {||
              prompt-header --left-char "┏"
            }
            $env.PROMPT_COMMAND_RIGHT = {|| try {
              jj --quiet --color always --ignore-working-copy log --no-graph --revisions @ --template '${/* jjtemplate */ ''
                separate(
                  " ",
                  if(empty, label("empty", "(empty)")),
                  coalesce(
                    surround(
                      "\"",
                      "\"",
                      if(
                        description.first_line().substr(0, 24).starts_with(description.first_line()),
                        description.first_line().substr(0, 24),
                        description.first_line().substr(0, 23) ++ "…"
                      )
                    ),
                    label(if(empty, "empty"), description_placeholder)
                  ),
                  bookmarks.join(", "),
                  change_id.shortest(),
                  commit_id.shortest(),
                  if(conflict, label("conflict", "(conflict)")),
                  if(divergent, label("divergent prefix", "(divergent)")),
                  if(hidden, label("hidden prefix", "(hidden)")),
                )
              ''}' err> $null_device
            } }

            $env.TRANSIENT_PROMPT_INDICATOR = "  "
            $env.TRANSIENT_PROMPT_INDICATOR_VI_INSERT = $env.TRANSIENT_PROMPT_INDICATOR
            $env.TRANSIENT_PROMPT_INDICATOR_VI_NORMAL = $env.TRANSIENT_PROMPT_INDICATOR
            $env.TRANSIENT_PROMPT_MULTILINE_INDICATOR = $env.TRANSIENT_PROMPT_INDICATOR
            $env.TRANSIENT_PROMPT_COMMAND = {||
              prompt-header --left-char "━"
            }
            $env.TRANSIENT_PROMPT_COMMAND_RIGHT = $env.PROMPT_COMMAND_RIGHT
          }
        ''
      }";
    };
}
