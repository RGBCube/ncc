{ self, ... }:
{
  flake.homeModules.shell = self.homeModules.prompt;
  flake.homeModules.prompt =
    { lib, pkgs, ... }:
    let
      inherit (lib.meta) getExe';
    in
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
                (if $code != 0 {
                  let signal = if $code < 0 or ($code > 128 and $code < 256) { try {
                    ^${getExe' pkgs.uutils-coreutils-noprefix "kill"} --list (if $code < 0 { 0 - $code } else { $code }) err> $null_device | str trim
                  } }

                  $"(ansi light_red_bold)(if ($signal | is-not-empty) { $"SIG($signal):" })($code)"
                })

                # COMMAND DURATION
                ($env.CMD_DURATION_MS
                | into int
                | $in * 1ms
                | if $in > 2sec { $"(ansi light_magenta_bold)($in)" })

                # BACKGROUND JOBS
                (job list | length | if $in > 0 { $"(ansi light_cyan_bold)jobs:($in)" })

                # NIX PACKAGES
                ($env.PATH
                | parse --regex "^/nix/store/[0-9a-z]{32}-(?<name>[^/]+?)(?:-(?<version>[0-9][^/-]*)(?:-[^/]+)?)?/bin/?$"
                | each {|package|
                  let name = $package.name | str replace --regex "-(un)?wrapped$" ""
                  $"($name)(if ($package.version | is-not-empty) { $":($package.version)" })"
                }
                | uniq
                | reverse
                | str join " "
                | if ($in | is-not-empty) { $"(ansi light_blue_bold)($in)" })
              ]
              | compact
              | each {|segment| $"┫(ansi reset)($segment)(ansi reset)(ansi light_yellow_bold)┣" }
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

                # DIRECTORY ACCESS
                (^${getExe' pkgs.uutils-coreutils-noprefix "test"} -w (pwd)
                | complete
                | if $in.exit_code != 0 { $"(ansi reset)(ansi light_red_bold)[readonly]" })
              ]
              | compact
              | str join $"(ansi reset) "
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
              jj --ignore-working-copy --no-integrate-operation --quiet --color always log --no-graph --revisions @ --template '${/* jjtemplate */ ''
                separate(
                  " ",
                  if(empty, label("empty", "(empty)")),
                  if(!empty, separate(
                    " ",
                    label("diff modified", "Δ" ++ self.diff().files().len()),
                    label("diff added", "+" ++ self.diff().stat().total_added()),
                    label("diff removed", "−" ++ self.diff().stat().total_removed()),
                  )),
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
                  if(conflict, label("conflict", "(conflict:" ++ self.conflicted_files().len() ++ ")")),
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
