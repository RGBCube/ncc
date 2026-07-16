{ self, lib, ... }:
let
  inherit (lib.attrsets) getAttr;
  inherit (lib.lists) concatMap singleton;
  inherit (lib.strings) concatLines;

  mkNixs = pkgs: self.packages.${pkgs.stdenv.hostPlatform.system}.nixs;

  allowed.commands = [
    "rg*"
    "ls*"

    "jj bookmark list*"
    "jj config get*"
    "jj config list*"
    "jj config path*"
    "jj diff*"
    "jj evolog*"
    "jj file annotate*"
    "jj file list*"
    "jj file search*"
    "jj file show*"
    "jj file track*"
    "jj git colocation status*"
    "jj git remote list*"
    "jj git root*"
    "jj help*"
    "jj interdiff*"
    "jj log*"
    "jj op diff*"
    "jj op log*"
    "jj op show*"
    "jj operation diff*"
    "jj operation log*"
    "jj operation show*"
    "jj resolve --list"
    "jj root*"
    "jj show*"
    "jj sparse list*"
    "jj st*"
    "jj status*"
    "jj tag list*"
    "jj util completion*"
    "jj util config-schema*"
    "jj util markdown-help*"
    "jj version*"
    "jj workspace list*"
    "jj workspace root*"

    "gh auth status*"
    "gh cache list*"
    "gh gist list*"
    "gh gist view*"
    "gh issue list*"
    "gh issue status*"
    "gh issue view*"
    "gh label list*"
    "gh pr checks*"
    "gh pr diff*"
    "gh pr list*"
    "gh pr status*"
    "gh pr view*"
    "gh release list*"
    "gh release view*"
    "gh repo list*"
    "gh repo view*"
    "gh ruleset check*"
    "gh ruleset list*"
    "gh ruleset view*"
    "gh run list*"
    "gh run view*"
    "gh search *"
    "gh status*"
    "gh variable get*"
    "gh variable list*"
    "gh workflow list*"
    "gh workflow view*"

    "cargo clippy*"
    "cargo nextest*"

    "nixs *"
  ];

  forbidden.rules = [
    {
      commands = singleton "git*";
      justification = "Use `jj` for version control.";
    }
    {
      commands = singleton "cargo check*";
      justification = "Use `cargo clippy` instead of `cargo check`.";
    }
    {
      commands = singleton "cargo test*";
      justification = "Use `cargo nextest` instead of `cargo test`.";
    }
    {
      commands = [
        "find /nix/store"
        "find /nix/store *"
        "find /nix/store/"
        "find /nix/store/ *"
      ];
      justification = "Do `find` over the entire `/nix/store`. Search specific store paths obtained from the flake instead.";
    }
  ];

  instructions =
    [
      "Use `nixs eval`."
      "Use `nixs flake archive`."
      "Use `nixs flake metadata`."
      "Use `nixs flake show`."
      "Use `nixs path-info`."
      "Prefer nix3 commands over nix2 commands."
    ]
    ++ (forbidden.rules |> map ({ justification, ... }: justification))
    |> map (instruction: ''
      - ${instruction}
    '')
    |> concatLines;

  allowed.paths = [
    "/etc/profiles"
    "/nix/store"
  ];
in
{
  flake.homeModules.opencode =
    { lib, pkgs, ... }:
    let
      inherit (lib.generators) toJSON;
      inherit (lib.trivial) const;
      inherit (lib.attrsets) genAttrs;
      inherit (lib.lists) singleton;
    in
    {
      packages = [
        pkgs.opencode
        (mkNixs pkgs)
      ];

      xdg.config.files."opencode/opencode.json".generator = toJSON { };
      xdg.config.files."opencode/opencode.json".value = {
        "$schema" = "https://opencode.ai/config.json";

        autoupdate = false;

        instructions = singleton "${pkgs.writeText "instructions.md" instructions}";

        permission = {
          "*" = "ask";
          codesearch = "allow";
          external_directory = genAttrs (map (path: "${path}/**") allowed.paths) (const "allow");
          glob = "allow";
          grep = "allow";
          list = "allow";
          lsp = "allow";
          read = "allow";
          task = "allow";
          todoread = "allow";
          todowrite = "allow";
          webfetch = "allow";
          websearch = "allow";

          bash =
            { }
            // genAttrs allowed.commands (const "allow")
            // genAttrs (forbidden.rules |> concatMap (getAttr "commands")) (const "deny");
        };
      };

      xdg.config.files."opencode/tui.json".generator = toJSON { };
      xdg.config.files."opencode/tui.json".value = {
        "$schema" = "https://opencode.ai/tui.json";
        theme = "system";
      };
    };

  flake.homeModules.codex =
    {
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) genAttrs;
      inherit (lib.strings)
        concatMapStringsSep
        removeSuffix
        splitString
        toJSON
        trim
        ;
      inherit (lib.trivial) const;
    in
    {
      packages = [
        pkgs.codex
        (mkNixs pkgs)
      ];

      xdg.config.files."codex/config.toml".type = "copy";
      xdg.config.files."codex/config.toml".generator = pkgs.writers.writeTOML "codex-config.toml";
      xdg.config.files."codex/config.toml".value = {
        approval_policy = "on-request";
        check_for_update_on_startup = false;
        commit_attribution = "";
        developer_instructions = instructions;

        history.persistence = "save-all";

        default_permissions = "default";
        permissions.default = {
          extends = ":workspace";

          filesystem = {
            ":root" = "deny";
            ":minimal" = "read";
            ":workspace_roots"."." = "write";
            ":workspace_roots".".git" = "write";
          }
          // genAttrs allowed.paths (const "read");

          network.enabled = true;
          network.domains."*" = "allow";
        };
      };

      xdg.config.files."codex/rules/default.rules".text =
        (
          forbidden.rules
          |> concatMapStringsSep "\n" (
            { justification, ... }@rule:
            rule.commands
            |> concatMapStringsSep "\n" (command: /* starlark */ ''
              prefix_rule(
                  pattern = ${
                    command
                    |> removeSuffix "*"
                    |> trim
                    |> splitString " "
                    |> toJSON
                  },
                  decision = "forbidden",
                  justification = ${toJSON justification},
              )
            '')
          )
        )
        + (
          allowed.commands
          |> concatMapStringsSep "\n" (command: /* starlark */ ''
            prefix_rule(
                pattern = ${
                  command
                  |> removeSuffix "*"
                  |> trim
                  |> splitString " "
                  |> toJSON
                },
                decision = "allow",
            )
          '')
        );
    };

  flake.homeModules.ai.imports = [
    self.homeModules.claude-code
    self.homeModules.opencode
  ];
  flake.homeModules.claude-code =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) strings;
      inherit (lib.generators) toJSON;
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe getExe';

      # Also 100% slop.
      statusLine = pkgs.writers.writeNuBin "claude-code-statusline" /* nu */ ''
        def format-duration [ms: int] {
          let total_s = $ms // 1000
          let h = $total_s // 3600
          let m = ($total_s mod 3600) // 60
          let s = $total_s mod 60
          if $h > 0 {
            $"($h)h($m | fill -a r -w 2 -c '0')m($s | fill -a r -w 2 -c '0')s"
          } else if $m > 0 {
            $"($m)m($s | fill -a r -w 2 -c '0')s"
          } else {
            $"($s)s"
          }
        }

        def color-for-pct [pct: number] {
          let pct_int = $pct | math floor | into int
          if $pct_int >= 80 {
            "\e[31m"
          } else if $pct_int >= 50 {
            "\e[33m"
          } else {
            "\e[32m"
          }
        }

        def format-rate-limits [input: record] {
          let session_pct = try { $input | get rate_limits.five_hour.used_percentage } catch { null }
          let week_pct = try { $input | get rate_limits.seven_day.used_percentage } catch { null }

          let session_part = if $session_pct != null {
            let c = color-for-pct $session_pct
            let v = $session_pct | math round --precision 0 | into int
            $"session: ($c)($v)%\e[0m"
          } else { "" }
          let week_part = if $week_pct != null {
            let c = color-for-pct $week_pct
            let v = $week_pct | math round --precision 0 | into int
            $"week: ($c)($v)%\e[0m"
          } else { "" }

          [$session_part $week_part] | where {|x| $x | is-not-empty} | str join " "
        }

        def get-jj-info [] {
          let root_result = do { jj root } | complete
          if $root_result.exit_code != 0 { return "" }

          let bookmark = (do { jj log -r @ --no-graph -T 'bookmarks.map(|b| b.name()).join(", ")' } | complete | get stdout | str trim)
          let change = (do { jj log -r @ --no-graph -T 'change_id.shortest(8)' } | complete | get stdout | str trim)
          let is_empty_str = (do { jj log -r @ --no-graph -T 'empty' } | complete | get stdout | str trim)
          let dirty = if $is_empty_str == "false" { "*" } else { "" }
          let has_conflict = (do { jj log -r @ --no-graph -T 'conflict' } | complete | get stdout | str trim)
          let conflict_marker = if $has_conflict == "true" { " \e[31m!conflict\e[0m" } else { "" }

          let ref_part = if ($bookmark | is-not-empty) {
            $" | \e[36m($bookmark)($dirty)\e[0m"
          } else if ($change | is-not-empty) {
            $" | \e[35m($change)($dirty)\e[0m"
          } else { "" }

          $"($ref_part)($conflict_marker)"
        }

        # --- Main ---
        let input = (^cat | from json)

        let usage_info = format-rate-limits $input

        let model_name = ($input | get model?.display_name? | default ($input | get model?.id? | default "unknown"))
        let used_pct = ($input | get context_window?.used_percentage? | default null)
        let total_cost = ($input | get cost?.total_cost_usd? | default 0)
        let total_input = ($input | get context_window?.s_in? | default ($input | get context_window?.total_input_tokens? | default 0))
        let total_output = ($input | get context_window?.s_out? | default ($input | get context_window?.total_output_tokens? | default 0))
        let duration_ms = ($input | get cost?.total_duration_ms? | default 0)
        let api_duration_ms = ($input | get cost?.total_api_duration_ms? | default 0)
        let lines_added = ($input | get cost?.total_lines_added? | default 0)
        let lines_removed = ($input | get cost?.total_lines_removed? | default 0)
        let exceeds_200k = ($input | get exceeds_200k_tokens? | default false)

        let cache_read = ($input | get context_window?.cache_read_tokens? | default 0)
        let cache_create = ($input | get context_window?.cache_creation_tokens? | default 0)

        let total_tokens = $total_input + $total_output

        def format-tokens [n: int] {
          if $n >= 1_000_000 {
            $"($n / 1_000_000.0 | math round --precision 1)M"
          } else if $n >= 1_000 {
            $"($n / 1_000.0 | math round --precision 1)k"
          } else {
            $"($n)"
          }
        }

        let in_display = (format-tokens ($total_input | into int))
        let out_display = (format-tokens ($total_output | into int))
        let tok_display = $"($in_display)/($out_display)"

        let cache_total = $cache_read + $cache_create
        let cache_display = if $cache_total > 0 {
          let cache_pct = ($cache_read * 100 / $cache_total | math round --precision 0 | into int)
          let cache_color = if $cache_pct >= 70 {
            "\e[32m"
          } else if $cache_pct >= 40 {
            "\e[33m"
          } else {
            "\e[31m"
          }
          $" cache:($cache_color)($cache_pct)%\e[0m"
        } else { "" }

        let context_display = if $used_pct != null {
          let color = color-for-pct $used_pct
          let pct_str = $used_pct | math round --precision 1
          $"($color)($pct_str)%\e[0m"
        } else { "--" }

        let cost_cents = ($total_cost * 100 | math round | into int)
        let cost_dollars = $cost_cents // 100
        let cost_frac = ($cost_cents mod 100 | math abs | into string | fill -a r -w 2 -c '0')
        let cost_display = $"$($cost_dollars).($cost_frac)"
        let elapsed_display = (format-duration ($duration_ms | into int))
        let wait_display = (format-duration ($api_duration_ms | into int))
        let churn_display = $"\e[32m+($lines_added)\e[0m/\e[31m-($lines_removed)\e[0m"
        let marker_200k = if $exceeds_200k { " | \e[31m!200k\e[0m" } else { "" }
        def format-cwd [dir: string] {
          if ($dir | is-empty) { return "" }
          let jj_root = try { do { cd $dir; jj workspace root } | complete } catch { {exit_code: 1, stdout: ""} }
          if $jj_root.exit_code == 0 {
            let root = ($jj_root.stdout | str trim)
            let home = ($env.HOME? | default "")
            let root_display = if ($home | is-not-empty) and ($root | str starts-with $home) {
              let rel = ($root | str replace $home "" | str trim -l -c '/')
              $"~/($rel)"
            } else {
              $root
            }
            let root_parts = ($root_display | split row "/")
            let base = if ($root_parts | length) <= 5 {
              $root_display
            } else {
              let tail = ($root_parts | last 5 | str join "/")
              $"…/($tail)"
            }
            let subpath = if ($dir | str starts-with $root) {
              $dir | str replace $root "" | str trim -l -c '/'
            } else { "" }
            if ($subpath | is-not-empty) {
              $"\e[36m($base)\e[0m → \e[34m($subpath)\e[0m"
            } else {
              $"\e[36m($base)\e[0m"
            }
          } else {
            let home = ($env.HOME? | default "")
            let display = if ($home | is-not-empty) and ($dir | str starts-with $home) {
              let rel = ($dir | str replace $home "" | str trim -l -c '/')
              $"~/($rel)"
            } else {
              $dir
            }
            let parts = ($display | split row "/")
            let shortened = if ($parts | length) <= 5 {
              $display
            } else {
              let tail = ($parts | last 5 | str join "/")
              $"…/($tail)"
            }
            $shortened
          }
        }

        let cwd_raw = ($input | get workspace?.current_dir? | default "")
        let cwd_display = if ($cwd_raw | is-not-empty) {
          let formatted = (format-cwd $cwd_raw)
          $" | ($formatted)"
        } else { "" }
        let jj_info = get-jj-info
        let quota_section = if ($usage_info | is-not-empty) {
          " | (usage) " + $usage_info
        } else { "" }

        print -n $"($model_name) | Ctx: ($context_display) | ($tok_display)($cache_display) | ($cost_display) | t:($elapsed_display) w:($wait_display) | ($churn_display)($marker_200k)($jj_info)($quota_section)($cwd_display)"
      '';
    in
    {
      xdg.config.files."claude-code/CLAUDE.md".text = instructions;

      xdg.config.files."claude-code/settings.json".type = "copy"; # Slop tries to write to the config directory :/.
      xdg.config.files."claude-code/settings.json".generator = toJSON { };
      xdg.config.files."claude-code/settings.json".value = {
        "$schema" = "https://json.schemastore.org/claude-code-settings.json";

        cleanupPeriodDays = 365 * 1000;

        permissions.allow =
          [ ]
          ++ map (cmd: "Bash(${cmd})") allowed.commands
          ++ map (path: "Read(${path}/**)") allowed.paths
          ++ [
            "Glob"
            "Grep"
            "LSP"
            "WebFetch"
            "WebSearch"
            "TaskCreate"
            "TaskUpdate"
            "TaskGet"
            "TaskList"
            "TaskOutput"
            "TaskStop"
          ];
        permissions.deny =
          forbidden.rules |> concatMap (rule: rule.commands |> map (command: "Bash(${command})"));

        env.CLAUDE_BASH_NO_LOGIN = "1";
        env.CLAUDE_CODE_EAGER_FLUSH = "1";
        env.CLAUDE_CODE_FORCE_GLOBAL_CACHE = "1";
        env.MCP_CONNECTION_NONBLOCKING = "1";
        env.USE_BUILTIN_RIPGREP = "0";

        # BETTER SLOPS
        alwaysThinkingEnabled = true;
        env.CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING = "1";
        env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
        env.CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY = "20";
        env.CLAUDE_CODE_PLAN_V2_AGENT_COUNT = "5";
        env.CLAUDE_CODE_PLAN_V2_EXPLORE_AGENT_COUNT = "5";
        env.DISABLE_AUTO_COMPACT = "1";
        env.ENABLE_MCP_LARGE_OUTPUT_FILES = "1";
        env.ENABLE_TOOL_SEARCH = "auto:5";
        env.MAX_THINKING_TOKENS = "31999";

        # LESS SLOPS
        skipWebFetchPreflight = true;
        env.CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";
        env.DISABLE_AUTOUPDATER = "1";
        env.DISABLE_ERROR_REPORTING = "1";
        env.DISABLE_INSTALLATION_CHECKS = "1";
        env.DISABLE_TELEMETRY = "1";

        # TOOLS
        hooks.WorktreeCreate = singleton {
          hooks = singleton {
            type = "command";
            command = /* bash */ ''jj workspace add "$(cat /dev/stdin | jq '.name' --raw-output)"'';
          };
        };
        hooks.WorktreeRemove = singleton {
          hooks = singleton {
            type = "command";
            command = /* bash */ ''jj workspace forget "$(cat /dev/stdin | jq '.worktree_path' --raw-output)"'';
          };
        };

        enabledPlugins."clangd-lsp@claude-plugins-official" = true;
        enabledPlugins."code-review@claude-plugins-official" = true;
        enabledPlugins."code-simplifier@claude-plugins-official" = true;
        enabledPlugins."kotlin-lsp@claude-plugins-official" = true;
        enabledPlugins."ralph-loop@claude-plugins-official" = true;
        enabledPlugins."rust-analyzer-lsp@claude-plugins-official" = true;

        # VISUAL UNSLOPS
        attribution.commit = "";
        attribution.pr = "";

        env.CLAUDE_CODE_DISABLE_TERMINAL_TITLE = "1";
        env.CLAUDE_CODE_HIDE_ACCOUNT_INFO = "1";
        env.DISABLE_COST_WARNINGS = "1";

        statusLine.type = "command";
        statusLine.command = getExe statusLine;

        spinnerVerbs.mode = "replace";
        spinnerVerbs.verbs = [
          "Redeeming"
          "Clodding"
          "Tokenmaxxing"
          "Slopping"
          "Clanking"
          "Churning"
          "Forgetting"
          "Splurging"
          "Ignoring GPL"
          "Increasing ram prices"
          "Making shit up"
          "Hallucinating"
          "Slopping"
          "Doing it"
          "Fucking shit up crazy style"
          "Hyprspacing"
          "Stealing"
          "Selling your data"
          "Outsourcing to Mossad"
          "Gemming it up"
          "Absolute coaling"
          "Truth nuking"
          "Fakecelling"
          "Truecelling"
          "Mogging"
        ];
      };

      packages =
        let
          # This is 100% slop but it doesn't matter.
          lift = pkgs.writeScriptBin "lift-claude-bun" /* py */ ''
            #!${getExe pkgs.python3}
            from __future__ import annotations

            # Extract the cli.js bundle from a bun --compile --bytecode executable.
            #
            # Starting with @anthropic-ai/claude-code 2.1.113 the npm package stopped
            # shipping cli.js and instead publishes platform-specific tarballs that contain
            # a bun-compiled ELF (~226 MB). The JavaScript is still fully embedded in the
            # binary as plaintext — the @bytecode marker just means a V8 parse-cache lives
            # alongside it, not instead of it.
            #
            # Layout of each CJS module inside the bun SEA payload:
            #   // @bun[ @bytecode] @bun-cjs\n
            #   (function(exports, require, module, __filename, __dirname) {<BODY>})\n
            #   \x00/$bunfs/root/<next-module-name>\x00...
            #
            # Claude Code ships three real modules in the tail region (past 0x6000000):
            # the main cli (~12 MB), then two tiny native-loader stubs for the optional
            # image-processor.node and audio-capture.node. Only the first is interesting.

            import sys
            from pathlib import Path

            # Skip over .rodata / .text — those contain `// @bun` string literals (error
            # messages, help text) that would confuse the scanner. The first real module
            # sat at ~0xd333ec8 in 2.1.113; staying well below that survives future growth.
            SCAN_FROM: int = 0x6000000

            HEADERS: list[bytes] = [
              b"// @bun @bytecode @bun-cjs\n(function(exports, require, module, __filename, __dirname) {",
              b"// @bun @bun-cjs\n(function(exports, require, module, __filename, __dirname) {",
            ]

            CJS_OPEN: bytes = b"(function(exports, require, module, __filename, __dirname) {"
            CJS_END: bytes = b"})\n\x00"


            def find_main_module(data: bytes) -> tuple[int, int]:
              # In 2.1.117 bun emits cli.js twice: once as a @bytecode blob with the V8
              # parse cache interleaved between the source and its `})\n\x00` terminator,
              # and again as a clean source-only copy that terminates normally. Collect
              # every header past SCAN_FROM and pick the first one whose terminator lies
              # before the next header — that's the source-only copy.
              headers: list[tuple[int, int]] = []
              for header in HEADERS:
                p: int = SCAN_FROM
                while True:
                  p = data.find(header, p)
                  if p < 0:
                    break
                  headers.append((p, len(header)))
                  p += 1

              if not headers:
                sys.exit("lift: no bun CJS module header found past 0x6000000")

              headers.sort()
              boundaries: list[int] = [p for p, _ in headers] + [len(data)]

              for idx, (start, _) in enumerate(headers):
                next_header: int = boundaries[idx + 1]
                end: int = data.find(CJS_END, start, next_header)
                if end >= 0:
                  return start, end + 3  # include })\n, exclude trailing NUL

              sys.exit("lift: could not find module terminator (})\\n\\x00)")


            def unwrap(mod: bytes) -> bytes:
              nl = mod.find(b"\n")
              if nl < 0:
                sys.exit("lift: module has no header newline")
              body = mod[nl + 1 :]
              if not body.startswith(CJS_OPEN):
                sys.exit("lift: module does not open with expected CJS wrapper")
              body = body[len(CJS_OPEN) :]
              # tail is either `})\n` or `})`
              if body.endswith(b"})\n"):
                body = body[:-3]
              elif body.endswith(b"})"):
                body = body[:-2]
              else:
                sys.exit("lift: module does not end with `})` wrapper close")
              return body


            def main() -> None:
              if len(sys.argv) != 3:
                sys.exit("usage: lift-claude-bun <claude-binary> <output.cjs>")

              binary = Path(sys.argv[1])
              output = Path(sys.argv[2])

              data = binary.read_bytes()
              start, end = find_main_module(data)
              body = unwrap(data[start:end])

              # Sanity: the real claude-code cli.js always contains this legal banner.
              if b"Anthropic" not in body[:4096]:
                sys.exit("lift: extracted body is missing Anthropic banner — layout changed?")

              output.write_bytes(body)
              sys.stderr.write(
                f"lifted {len(body):,} bytes from {binary.name} "
                f"(module @ {start:#x}..{end:#x}) -> {output}\n"
              )


            if __name__ == "__main__":
              main()
          '';

          patch = pkgs.writeScriptBin "patch-claude-code-src" /* py */ ''
            #!${getExe pkgs.python3}
            from __future__ import annotations

            import re
            import sys
            from collections.abc import Callable
            from pathlib import Path
            from typing import Union

            type Replacement = Union[bytes, Callable[[re.Match[bytes]], bytes]]

            W: bytes = rb"[\w$]+"
            # Qualified name: matches `FN` and also `NS.FN` (e.g. `Lf.join`, `Oc7.spawn`).
            # Since 2.1.113 bun's bundler emits more member-style calls for path/spawn helpers.
            Q: bytes = rb"[\w$]+(?:\.[\w$]+)*"
            data: bytes = Path(sys.argv[1]).read_bytes()

            SEARCH_WINDOW: int = 500


            def log(msg: str) -> None:
              sys.stderr.write(msg + "\n")


            def patch(label: str, pattern: bytes, replacement: Replacement) -> None:
              global data
              data, n = re.subn(pattern, replacement, data)
              log(f"{label} ({n})")


            def replace(label: str, old: bytes, new: bytes) -> None:
              global data
              n: int = data.count(old)
              if n == 0:
                log(f"{label}: NOT FOUND")
                return
              data = data.replace(old, new)
              log(f"{label} ({n})")


            def flip_gates(gates: list[tuple[bytes, str]]) -> None:
              """Flip all gate defaults from false to true in a single regex pass."""
              global data
              gate_keys: list[bytes] = [g for g, _ in gates]
              labels: dict[bytes, str] = dict(gates)
              alternation: bytes = b"|".join(re.escape(g) for g in gate_keys)
              pat: bytes = W + rb'\("(' + alternation + rb')",!1\)'
              flipped: set[bytes] = set()

              def replacer(m: re.Match[bytes]) -> bytes:
                flipped.add(m.group(1))
                return m[0].replace(b",!1)", b",!0)")

              data, n = re.subn(pat, replacer, data)
              log(f"feature gates: {n} flipped across {len(flipped)} gates")
              for key in gate_keys:
                status = "ok" if key in flipped else "MISSED"
                log(f"  {labels[key]} [{status}]")


            # --- AGENTS.md support ---
            # The CLAUDE.md loader only reads CLAUDE.md. Patch it to also load AGENTS.md
            # from the same directories. Pattern: let VAR=ME(DIR,"CLAUDE.md");ARR.push(...await XE(VAR,"Project",ARG,BOOL))

            agents_pat: bytes = (
              rb"let (" + W + rb")=(" + Q + rb")\((" + W + rb'),"CLAUDE\.md"\);'
              rb"(" + W + rb")\.push\(\.\.\.await (" + W + rb")\(\1,\"Project\",(" + W + rb"),(" + W + rb")\)\)"
            )


            def agents_repl(m: re.Match[bytes]) -> bytes:
              var, join_fn, dir_, arr, load_fn, arg, flag = [m.group(i) for i in range(1, 8)]
              return (
                b'for(let _f of["CLAUDE.md","AGENTS.md"]){let '
                + var + b"=" + join_fn + b"(" + dir_ + b",_f);"
                + arr + b".push(...await " + load_fn + b"(" + var + b',"Project",' + arg + b"," + flag + b"))}"
              )


            patch("agents.md loader", agents_pat, agents_repl)

            # --- macOS config path ---

            replace(
              "macOS config path",
              b'case"macos":return"/Library/Application Support/ClaudeCode"',
              b'case"macos":return"/etc/claude-code"',
            )

            # --- Enable hard-disabled slash commands ---

            slash_commands: list[tuple[bytes, str]] = [
              (b'name:"btw",description:"Ask a quick side question', "/btw"),
            ]

            for anchor, label in slash_commands:
              pos: int = data.find(anchor)
              if pos < 0:
                log(f"slash command {label}: NOT FOUND")
                continue
              window: bytes = data[pos : pos + SEARCH_WINDOW]
              patched: bytes = window.replace(b"isEnabled:()=>!1", b"isEnabled:()=>!0", 1)
              if patched == window:
                log(f"slash command {label}: isEnabled not found in window")
                continue
              data = data[:pos] + patched + data[pos + SEARCH_WINDOW :]
              log(f"slash command {label}: enabled")

            # --- Force the async feature-gate resolver to resolve true when offline ---
            # The ASYNC gate resolver (Av → YB across versions) falls back to its default
            # when telemetry is off (`if(!p4())return!1`), so every gate it resolves reads
            # false. In 2.1.181 it shares its `tHt()`/`nHt()` override-map preamble with a
            # SIBLING resolver (X1r) that resolves `tengu_disable_bypass_permissions_mode`
            # — forcing THAT one true would DISABLE bypass-permissions mode. So we can't
            # match on the shared preamble or replace the whole body; instead we flip only
            # the offline fallback inside the resolver whose tail reads
            # `cachedGrowthBookFeatures?.[e]===!0` (YB), leaving X1r and the explicit
            # override maps untouched.
            #
            # YB's only call-sites all target gates we want enabled:
            #  - tengu_ccr_bridge              → bridge auto-connect
            #  - tengu_ccr_bundle_seed_enabled → CCR bundle seed
            #  - tengu_harbor                  → plugin marketplace
            # Flipping the fallback to !0 enables these; explicit `tHt`/`nHt` overrides
            # still win, so an intentionally-disabled gate stays disabled.

            replace(
              "async gate offline fallback true",
              b"if(!p4())return!1;if(vt().cachedGrowthBookFeatures?.[e]===!0)",
              b"if(!p4())return!0;if(vt().cachedGrowthBookFeatures?.[e]===!0)",
            )

            # --- Restore 1h prompt cache TTL when telemetry is off ---
            # https://github.com/anthropics/claude-code/issues/45381
            # The GrowthBook allowlist for "ttl":"1h" cache_control falls back to the
            # default object when telemetry is off. Anthropic now ships
            # {allowlist:["repl_main_thread*","sdk","auto_mode"]} as the default (up
            # from the broken {} in earlier versions), so the TUI and SDK already get
            # 1h TTL — but batch agents and less-common query sources still miss.
            # Widen the default to ["*"] so everything matches.

            patch(
              "1h prompt cache TTL fallback",
              rb'(' + W + rb')\("tengu_prompt_cache_1h_config",\{allowlist:\[[^\]]+\]\}\)\.allowlist\?\?\[\]',
              lambda m: m[1] + b'("tengu_prompt_cache_1h_config",{allowlist:["*"]}).allowlist??[]',
            )

            # --- Fix Deno-compile bridge spawn ---
            # Deno-compiled binaries eat --flags as V8 args, so we route spawns through
            # env(1) to pass them as normal CLI flags instead.

            patch(
              "deno bridge spawn fix",
              rb"let (" + W + rb")=(" + Q + rb")\((" + W + rb")\.execPath,(" + W + rb"),",
              lambda m: (
                b"let "
                + m[1]
                + b"="
                + m[2]
                + b'("env",["--",'
                + m[3]
                + b".execPath,..."
                + m[4]
                + b"],"
              ),
            )

            # --- Flip feature gates ---
            # DISABLE_TELEMETRY=1 prevents GrowthBook feature flag resolution, so all gates
            # fall back to their hardcoded defaults (false). Flip them to true.

            Gate = tuple[bytes, str]

            core_gates: list[Gate] = [
              (b"tengu_ccr_bridge", "remote control"),
              (b"tengu_bridge_system_init", "bridge SDK init on connect"),
              (b"tengu_bridge_requires_action_details", "bridge rich tool-use payloads"),
              (b"tengu_remote_backend", "remote backend"),
              (b"tengu_immediate_model_command", "instant /model switching"),
              (b"tengu_fgts", "fine-grained tool streaming"),
              (b"tengu_surreal_dali", "scheduled agents/cron"),
            ]

            memory_gates: list[Gate] = [
              # (b"tengu_session_memory", "session memory"),  # auto-memory; pollutes unrelated convos
              (b"tengu_herring_clock", "team memory directory"),
              (b"tengu_passport_quail", "typed combined memory prompts"),
              (b"tengu_paper_halyard", "memory dedup in nested dirs"),
            ]

            ux_gates: list[Gate] = [
              (b"tengu_kairos_brief", "brief output mode"),
              (b"tengu_kairos_loop_dynamic", "/loop dynamic self-pacing"),
              (b"tengu_kairos_loop_persistent", "/loop persistent mode"),
              (b"tengu_kairos_loop_prompt", "/loop prompt sentinel"),
              (b"tengu_terminal_sidebar", "status in terminal tab"),
              (b"tengu_destructive_command_warning", "destructive command warnings"),
              (b"tengu_amber_prism", "permission denial context"),
              (b"tengu_hawthorn_steeple", "context windowing"),
              (b"tengu_verified_vs_assumed", "verified-vs-assumed reporting"),
              # tengu_pewter_brook (fullscreen TUI default) disabled — Ink fullscreen
              # rendering drops memoized Text children in nested Box columns (/usage
              # loses its "What's contributing..." bold header, big vertical gaps).
              # Re-enable by setting `tui: "fullscreen"` in settings.json if desired.
            ]

            tool_gates: list[Gate] = [
              (b"tengu_chrome_auto_enable", "auto-enable chrome devtools"),
              (b"tengu_plum_vx3", "web search reranking"),
              # (b"tengu_moth_copse", "relevant memory recall"),  # auto-recall; pollutes unrelated convos
              (b"tengu_harbor", "plugin marketplace"),
              (b"tengu_harbor_permissions", "plugin permissions"),
              (b"tengu_relay_chain_v1", "parallel command chaining guidance"),
              (b"tengu_edit_minimalanchor_jrn", "Edit tool minimal-anchor instructions"),
              (b"tengu_amber_sentinel", "Monitor tool for streaming bg scripts"),
              (b"tengu_skills_dashboard_enabled", "/skills dashboard"),
            ]

            flip_gates(core_gates + memory_gates + ux_gates + tool_gates)

            # --- Disable the claude-api bundled skill ---
            # Registered via vA({name:"claude-api",description:v4_,...}) at bundle-load
            # time. The description (v4_) is a ~200-token SDK/Bedrock usage matrix with
            # TRIGGER/SKIP rules that gets injected into every system prompt. We don't
            # write Anthropic SDK code in this environment, so cut it. Renamed from
            # `claude-developer-platform` in an earlier release — match on current name.

            patch(
              "disable claude-api skill",
              # Skill registrations now carry a `menuDescription` field ahead of the
              # injected `description` (2.1.181), so anchor on that.
              rb'(' + W + rb')\(\{name:"claude-api",menuDescription:',
              lambda m: m[1] + b'({name:"claude-api",isEnabled:()=>!1,menuDescription:',
            )

            # --- grep/find/rg shim: delegate to absolute Nix store paths ---
            # claude-code ships a shell shim factory that emits bash functions
            # which redefine `grep`/`find`/`rg` to re-exec the claude binary
            # with argv[0]=ugrep/bfs/rg. In Bun "ant-native" builds this
            # dispatches to bundled native tools. The Deno repack drops those,
            # so invocations fail with `error: unknown option '-G'`. Replace the
            # factory's body so it emits bash that calls the real tools directly
            # via their Nix store paths.
            #
            # 2.1.181 rewrote the factory (a38 `(H,_,q=[])` → `Fzr(e,t,n=[],r=[])`):
            # e=command name (grep/find/rg), t=ARGV0/real-tool name (ugrep/bfs/rg),
            # n=default args, r=passthrough glob patterns (dropped — the real tool
            # supports those flags). The emitted bash also changed shape (env-var
            # override + zsh/win/exec branches, header `\x60function ''${e} {`).
            #
            # Anchor on (a) the four-param `(W,W,W=[],W=[])` signature — unique to
            # this factory in 2.1.181 — and (b) the `\x60function ''${e} {` bash
            # header it MUST emit, where e is the first param (captured, since names
            # rotate across versions). Brace-balanced parsing finds the body end so
            # internal restructures don't break us. We reconstruct the whole function
            # with our own param names (call sites pass positionally) so it emits a
            # single-line bash function that execs the real store tool, falling back
            # to `command <name>` when the store path is missing.

            def scan_js_block(blob: bytes, pos: int) -> int:
              """Return the offset just past the `}` closing the `{` at pos-1.
              Tracks '...' / "..." / `...` (with ''${...} interpolations) so
              braces inside strings don't count. Bun output has no comments or
              regex literals in this region, so we don't track those."""
              depth: int = 1
              while pos < len(blob):
                c: bytes = blob[pos:pos + 1]
                if c == b"{":
                  depth += 1
                elif c == b"}":
                  depth -= 1
                  if depth == 0:
                    return pos + 1
                elif c in (b"'", b'"'):
                  pos += 1
                  while pos < len(blob) and blob[pos:pos + 1] != c:
                    pos += 2 if blob[pos:pos + 1] == b"\\" else 1
                elif c == b"\x60":
                  pos += 1
                  while pos < len(blob) and blob[pos:pos + 1] != b"\x60":
                    if blob[pos:pos + 1] == b"\\":
                      pos += 2
                    elif blob[pos:pos + 2] == b"''${":
                      pos += 2
                      inner: int = 1
                      while pos < len(blob) and inner > 0:
                        ic: bytes = blob[pos:pos + 1]
                        if ic == b"{":
                          inner += 1
                        elif ic == b"}":
                          inner -= 1
                        pos += 1
                      continue
                    else:
                      pos += 1
                pos += 1
              sys.exit("grep/find/rg shim: unbalanced braces")


            fzr_sig: bytes = (
              rb"function (" + W + rb")\((" + W + rb"),(" + W + rb"),("
              + W + rb")=\[\],(" + W + rb")=\[\]\)\{"
            )
            fzr_match: re.Match[bytes] | None = None
            for cand in re.finditer(fzr_sig, data):
              if b"\x60function ''${" + cand.group(2) + b"} {" in data[cand.end():cand.end() + 800]:
                fzr_match = cand
                break

            if fzr_match is None:
              log("grep/find/rg shim: NOT FOUND")
            else:
              fn_name: bytes = fzr_match.group(1)
              body_end: int = scan_js_block(data, fzr_match.end())
              fzr_new: bytes = (
                b"function " + fn_name + b"(e,t,n=[],r=[]){"
                b'let o=n.length>0?n.join(" ")+\' "$@"\':\'"$@"\';'
                b'let P=({ugrep:"${getExe' pkgs.ugrep "ugrep"}",'
                b'bfs:"${getExe pkgs.bfs}",'
                b'rg:"${getExe pkgs.ripgrep}"})[t]||t;'
                b'return "function "+e+" { if ! [ -x "+P+" ]; then command "+e+\' "$@"; return; fi; \'+P+" "+o+"; }"}'
              )
              data = data[:fzr_match.start()] + fzr_new + data[body_end:]
              log(f"grep/find/rg shim: replaced {fn_name.decode()}")

            # --- Bun runtime polyfill ---
            # Since 2.1.128 the bundle calls Bun.* APIs unguarded (Bun.stringWidth,
            # Bun.semver, Bun.hash, Bun.spawn, Bun.YAML, Bun.Transpiler, Bun.listen,
            # Bun.which, Bun.wrapAnsi, Bun.stripANSI, Bun.embeddedFiles, Bun.gc,
            # Bun.generateHeapSnapshot, Bun.JSONL, Bun.Terminal, Bun.version). Under
            # Deno these throw `ReferenceError: Bun is not defined` at first use
            # (Bun.stringWidth fires in a column-width helper during banner render).
            # Define globalThis.Bun upfront with Node-backed equivalents so bare
            # `Bun.X` lookups resolve.
            #
            # Bun.Terminal and Bun.JSONL are intentionally left absent: the bundle
            # already has fallback paths gated on `typeof Bun.Terminal<"u"` and
            # `Bun.JSONL?.parseChunk`, so leaving them undefined preserves the
            # built-in "running under Node?" degradation rather than half-emulating.

            bun_shim: bytes = rb"""(()=>{if(typeof globalThis.Bun!=="undefined")return;
            const sw=require("string-width"),sa=require("strip-ansi"),wa=require("wrap-ansi");
            const sv=require("semver"),ya=require("yaml");
            const cp=require("child_process"),fs=require("fs"),path=require("path");
            const crypto=require("crypto"),net=require("net");
            function bunHash(input){const buf=Buffer.isBuffer(input)?input:Buffer.from(typeof input==="string"?input:String(input));return crypto.createHash("sha1").update(buf).digest().readBigUInt64LE(0);}
            function bunSpawn(cmd,opts){opts=opts||{};const[bin,...args]=cmd;const stdio=["pipe","pipe",opts.stderr==="ignore"?"ignore":"pipe"];const child=cp.spawn(bin,args,{cwd:opts.cwd,env:opts.env||process.env,stdio,argv0:opts.argv0});const exited=new Promise(r=>child.on("exit",c=>r(c==null?1:c)));return{pid:child.pid,stdin:child.stdin,stdout:child.stdout,stderr:child.stderr,exitCode:null,killed:false,kill(s){try{child.kill(s)}catch{}this.killed=true},async wait(){return await exited},exited};}
            function bunListen(opts){const h=opts.socket||{};const server=net.createServer(s=>{s.data=undefined;if(h.open)try{h.open(s)}catch{}s.on("data",d=>h.data&&h.data(s,d));s.on("close",()=>h.close&&h.close(s));s.on("error",e=>h.error&&h.error(s,e));});server.listen(opts.port||0,opts.hostname||"127.0.0.1");return server;}
            class BunTranspiler{constructor(o){this.opts=o}transformSync(s){return s}}
            globalThis.Bun={version:"1.3.13",embeddedFiles:[],stringWidth:(s,o)=>sw(String(s||""),o),stripANSI:s=>sa(String(s||"")),wrapAnsi:(s,w,o)=>wa(String(s||""),w,o),semver:{satisfies:(a,b)=>sv.satisfies(a,b),order:(a,b)=>sv.compare(a,b)},hash:bunHash,which(cmd){const dirs=(process.env.PATH||"").split(path.delimiter);for(const d of dirs){const f=path.join(d,cmd);try{fs.accessSync(f,fs.constants.X_OK);return f;}catch{}}return null;},spawn:bunSpawn,listen:bunListen,YAML:{parse:s=>ya.parse(s),stringify:(o,r,i)=>ya.stringify(o,r,i)},Transpiler:BunTranspiler,generateHeapSnapshot:()=>new ArrayBuffer(0),gc:()=>{}};
            })();
            """

            data = bun_shim + data
            log("Bun runtime polyfill: prepended")

            Path(sys.argv[1]).write_bytes(data)
          '';
        in
        [
          (pkgs.writers.writeNuBin "claude" /* nu */ ''
            def detect-platform []: nothing -> string {
              let arch = match ($nu.os-info.arch | str downcase) {
                "x86_64" | "x64" | "amd64" => "x64"
                "aarch64" | "arm64" => "arm64"
                $arch => {
                  print --stderr $"(ansi red_bold)error:(ansi reset) unsupported arch: ($arch)"
                  exit 67
                }
              }

              match ($nu.os-info.name | str downcase) {
                "linux" => $"linux-($arch)"
                "macos" | "darwin" => $"darwin-($arch)"
                $os => {
                  print --stderr $"(ansi red_bold)error:(ansi reset) unsupported os: ($os)"
                  exit 67
                }
              }
            }

            def detect-version [--cache: directory, --rebuild]: nothing -> string {
              let version_file = $cache | path join "latest-version"

              match ($rebuild or (try { (date now) - (ls $version_file | get 0.modified) > 6hr } | default true)) {
                # Version older than 6h or doesn't exist.
                true | null => {
                  let version = try {
                    http get --max-time 5sec https://registry.npmjs.org/@anthropic-ai/claude-code/latest | get version
                  } catch {
                    print --stderr $"(ansi yellow_bold)warn:(ansi reset) fetched version older than 6hr, but can't re-fetch"
                    return ""
                  }

                  try {
                    $version_file | path parse | get parent | mkdir $in
                    $version | save --force $version_file
                  } catch {
                    print --stderr $"(ansi yellow_bold)warn:(ansi reset) failed to save latest fetched version"
                  }

                  $version
                },

                # Version fetched within 6h.
                false => { try {
                  open $version_file
                } catch {
                  print --stderr $"(ansi yellow_bold)warn:(ansi reset) failed to read latest fetched version"
                  ""
                } },
              }
            }

            def run-latest [--cache: directory, ...arguments] {
              print --stderr $"(ansi yellow_bold)warn:(ansi reset) falling back to latest binary"

              try {
                let latest = ls --long ($cache | path join "claude-code-*" | into glob)
                | where { $in.type == "file" and ($in.mode | str substring 2..<3) == "x" }
                | sort-by modified
                | last
                | get name
                exec $latest ...$arguments
              } catch {
                print --stderr $"(ansi red_bold)error:(ansi reset) no binary found"
                exit 67
              }
            }

            def --wrapped main [--rebuild, ...arguments] {
              let cache = $env
              | get --optional "XDG_CACHE_HOME"
              | default ($env.HOME | path join ".cache")
              | path join "claude-code"

              let version = detect-version --cache $cache --rebuild=($rebuild)
              if ($version | is-empty) { run-latest --cache $cache ...$arguments }

              let binary_path = $cache | path join $"claude-code-($version)"

              if not ($binary_path | path exists) or $rebuild {
                let archive = $"($binary_path).tar.gz"

                if not ($archive | path exists) or $rebuild {
                  let platform = detect-platform

                  try {
                    http get --raw $"https://registry.npmjs.org/@anthropic-ai/claude-code-($platform)/-/claude-code-($platform)-($version).tgz"
                    | save --force --raw $archive
                  } catch {
                    print --stderr $"(ansi yellow_bold)warn:(ansi reset) failed to download tarball"
                    run-latest --cache $cache ...$arguments
                  }
                }

                let workdir = $cache | path join $"claude-code-($version)-workdir"
                rm --recursive --force $workdir
                mkdir $workdir

                ^${getExe pkgs.gnutar} --extract --gzip --file $archive --directory $workdir
                rm $archive

                let cli = $workdir | path join "cli.cjs"
                ^${getExe lift} ($workdir | path join "package" "claude") $cli
                ^${getExe patch} $cli

                r###'${
                  strings.toJSON {
                    name = "claude-code-lifted";
                    type = "commonjs";
                    dependencies = {
                      ws = "^8";
                      undici = "^6";
                      node-fetch = "^3";
                      ajv = "^8";
                      ajv-formats = "^3";
                      yaml = "^2";
                      # Bun shim deps (see "Bun runtime polyfill" in patch script).
                      # Pinned to CJS-compatible majors: ESM-only releases
                      # (string-width@5+, strip-ansi@7+, wrap-ansi@8+) break
                      # require() inside cli.cjs.
                      string-width = "^4";
                      strip-ansi = "^6";
                      wrap-ansi = "^7";
                      semver = "^7";
                    };
                  }
                }'### | save --force ($workdir | path join "package.json")

                $env.DENO_DIR = ($workdir | path join ".deno")
                (^"${getExe pkgs.deno}" install
                  --quiet
                  --node-modules-dir=auto
                  --entrypoint $cli)
                (^"${getExe pkgs.deno}" compile
                  --quiet
                  --allow-all
                  --node-modules-dir=auto
                  --include ($workdir | path join "node_modules")
                  --output $binary_path
                  $cli)

                rm --recursive --force $workdir
              }

              r###'${
                strings.toJSON config.xdg.config.files."claude-code/settings.json".value.env
              }'### | from json | load-env

              exec $binary_path ...$arguments
            }
          '')

          (mkNixs pkgs)
        ];
    };
}
