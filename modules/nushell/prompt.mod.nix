{
  flake.homeModules.prompt =
    { pkgs, ... }:
    {
      programs.nushell.extraConfig = "source ${
        pkgs.writeText "prompt.nu" /* nu */ ''
          do --env {
            use std null_device

            def prompt-header [
              --left-char: string
            ]: nothing -> string {
              let code = $env.LAST_EXIT_CODE

              let jj_workspace_root = try {
                jj workspace root err> $null_device
              } catch {
                ""
              }

              let hostname = if ($env.SSH_CONNECTION? | is-not-empty) {
                let hostname = try {
                  hostname
                } catch {
                  "remote"
                }

                $"(ansi light_green_bold)@($hostname)(ansi reset) "
              } else {
                ""
              }

              let body = if ($jj_workspace_root | is-not-empty) {
                let subpath = pwd | path relative-to $jj_workspace_root
                let subpath = if ($subpath | is-not-empty) {
                  $"(ansi magenta_bold) → (ansi reset)(ansi blue)($subpath)"
                }

                $"($hostname)(ansi light_yellow_bold)($jj_workspace_root | path basename)($subpath)(ansi reset)"
              } else {
                $"($hostname)(ansi cyan)(
                  if (pwd | str starts-with $env.HOME) {
                    "~" | path join (pwd | path relative-to $env.HOME)
                  } else {
                    pwd
                  }
                )(ansi reset)"
              }

              let command_duration = ($env.CMD_DURATION_MS | into int) * 1ms
              let command_duration = if $command_duration <= 2sec {
                ""
              } else {
                $"┫(ansi light_magenta_bold)($command_duration)(ansi light_yellow_bold)┣━"
              }

              let exit_code = if $code == 0 {
                ""
              } else {
                $"┫(ansi light_red_bold)($code)(ansi light_yellow_bold)┣━"
              }

              let middle = if $command_duration == "" and $exit_code == "" {
                "━"
              } else {
                ""
              }

              $"(ansi light_yellow_bold)($left_char)($exit_code)($middle)($command_duration)(ansi reset) ($body)(char newline)"
            }

            $env.PROMPT_INDICATOR = $"(ansi light_yellow_bold)┃(ansi reset) "
            $env.PROMPT_INDICATOR_VI_NORMAL = $env.PROMPT_INDICATOR
            $env.PROMPT_INDICATOR_VI_INSERT = $env.PROMPT_INDICATOR
            $env.PROMPT_MULTILINE_INDICATOR = $env.PROMPT_INDICATOR
            $env.PROMPT_COMMAND = {||
              prompt-header --left-char "┏"
            }
            $env.PROMPT_COMMAND_RIGHT = {||
              let jj_status = try {
                jj --quiet --color always --ignore-working-copy log --no-graph --revisions @ --template '
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
                ' err> $null_device
              } catch {
                ""
              }

              $jj_status
            }

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
      }\n";
    };
}
