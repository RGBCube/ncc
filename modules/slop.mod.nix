let
  commands.allowed = [
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
    "cargo check*"
  ];
in
{
  flake.homeModules.opencode =
    { lib, pkgs, ... }:
    let
      inherit (lib.generators) toJSON;
      inherit (lib.trivial) const;
      inherit (lib.attrsets) genAttrs;
    in
    {
      packages = [
        pkgs.opencode
      ];

      xdg.config.files."opencode/opencode.json".generator = toJSON { };
      xdg.config.files."opencode/opencode.json".value = {
        "$schema" = "https://opencode.ai/config.json";

        autoupdate = false;

        permission = {
          "*" = "ask";
          codesearch = "allow";
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

          bash = genAttrs commands.allowed (const "allow");
        };
      };
    };

  flake.homeModules.claude-code =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.generators) toJSON;
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe;

      # Also 100% slop.
      statusLine = pkgs.writeScriptBin "claude-code-statusline" /* nu */ ''
        #!${getExe pkgs.nushell}

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

        def read-usage [] {
            # Reads from the shared cache file written by the patched cli.js oauth/usage
            # fetch function. No direct API calls — cli.js is the single writer.
            let cache_file = "/tmp/.claude-usage.json"
            if not ($cache_file | path exists) { return "" }

            let usage_json = try { open $cache_file } catch { return "" }

            let session_pct = try { $usage_json | get five_hour.utilization } catch { null }
            let week_pct = try { $usage_json | get seven_day.utilization } catch { null }

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

        # Usage quota (reads shared cache written by cli.js)
        let usage_info = read-usage

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
      xdg.config.files."claude-code/settings.json".type = "copy"; # Slop tries to write to the config directory :/.
      xdg.config.files."claude-code/settings.json".generator = toJSON { };
      xdg.config.files."claude-code/settings.json".value = {
        "$schema" = "https://json.schemastore.org/claude-code-settings.json";

        permissions.allow = map (cmd: "Bash(${cmd})") commands.allowed ++ [
          "Glob"
          "Grep"
          "Read"
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
        env.CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
        env.DISABLE_AUTOUPDATER = "1";
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
        enabledPlugins."context7@claude-plugins-official" = true;
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
        ];
      };

      packages =
        let
          # This is 100% slop but it doesn't matter.
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
            data: bytes = Path(sys.argv[1]).read_bytes()

            SEARCH_WINDOW: int = 500


            def log(msg: str) -> None:
              sys.stderr.write(msg + "\n")


            def patch(label: str, pattern: bytes, replacement: Replacement) -> None:
              global data
              data, n = re.subn(pattern, replacement, data)
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


            # --- AGENTS.md support: claude can now load AGENTS.md alongside CLAUDE.md for project configs ---

            agents_pat: bytes = (
              rb"let (" + W + rb")=(" + W + rb")\((" + W + rb'),"CLAUDE\.md"\);'
              rb"(" + W + rb")\.push\(\.\.\.(" + W + rb')\(\1,"Project",([^)]+)\)\)'
            )


            def agents_repl(m: re.Match[bytes]) -> bytes:
              var, path_join, dir_, arr, load_fn, tail = [m.group(i) for i in range(1, 7)]
              return (
                b'for(let _f of["CLAUDE.md","AGENTS.md"]){let '
                + var
                + b"="
                + path_join
                + b"("
                + dir_
                + b",_f);"
                + arr
                + b".push(..."
                + load_fn
                + b"("
                + var
                + b',"Project",'
                + tail
                + b"))}"
              )


            patch("agents.md loader", agents_pat, agents_repl)

            # --- macOS config path: use /etc/claude-code instead of ~/Library/Application Support because the latter is retarded for cli tools ---

            data = data.replace(
              b'case"macos":return"/Library/Application Support/ClaudeCode"',
              b'case"macos":return"/etc/claude-code"',
            )

            # --- Enable hard-disabled slash commands: /btw, /files, /tag ---

            slash_commands: list[tuple[bytes, str]] = [
              (b'name:"btw",description:"Ask a quick side question', "/btw"),
              (b'name:"files",description:"List all files currently in context"', "/files"),
              (b'name:"tag",userFacingName', "/tag"),
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

            # --- Bypass thinkback gate (no default arg, different replacement strategy) ---

            patch("thinkback gate", W + rb'\("tengu_thinkback"\)', b'!0||"tengu_thinkback"')

            # --- Fix Deno-compile bridge spawn ---
            # Deno-compiled binaries eat --flags as V8 args, so we route spawns through
            # env(1) to pass them as normal CLI flags instead.

            patch(
              "deno bridge spawn fix",
              rb"let (" + W + rb")=(" + W + rb")\((" + W + rb")\.execPath,(" + W + rb"),",
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
              (b"tengu_cobalt_compass", "1M context window"),
              (b"tengu_ccr_bridge", "remote control"),
              (b"tengu_remote_backend", "remote backend"),
              (b"tengu_keybinding_customization_release", "custom keybindings"),
              (b"tengu_streaming_text", "token-by-token streaming"),
              (b"tengu_immediate_model_command", "instant /model switching"),
              (b"tengu_fgts", "fine-grained tool streaming"),
            ]

            memory_gates: list[Gate] = [
              (b"tengu_session_memory", "session memory"),
              (b"tengu_sm_compact", "memory survives compaction"),
              (b"tengu_compact_cache_prefix", "cache-aware compaction"),
              (b"tengu_compact_streaming_retry", "compact stream retry"),
              (b"tengu_pebble_leaf_prune", "message pruning"),
            ]

            ux_gates: list[Gate] = [
              (b"tengu_coral_fern", "grep hints in prompt"),
              (b"tengu_sotto_voce", "output efficiency"),
              (b"tengu_kairos_brief", "brief output mode"),
              (b"tengu_bergotte_lantern", "concise polished output"),
              (b"tengu_permission_explainer", "permission explanations"),
              (b"tengu_destructive_command_warning", "destructive command warnings"),
              (b"tengu_pr_status_cli", "PR status footer"),
              (b"tengu_copper_wren", "edit feedback messages"),
              (b"tengu_quiet_hollow", "thinking summaries"),
              (b"tengu_lean_cast", "lean system prompt"),
              (b"tengu_amber_prism", "permission denial context"),
            ]

            tool_gates: list[Gate] = [
              (b"tengu_mcp_elicitation", "MCP tool prompting"),
              (b"tengu_tool_input_aliasing", "param alias resolution"),
              (b"tengu_chrome_auto_enable", "auto-enable chrome devtools"),
              (b"tengu_copper_bridge", "chrome bridge context"),
              (b"tengu_system_prompt_global_cache", "global system prompt cache"),
              (b"tengu_tst_hint_m7r", "tool search hints"),
              (b"tengu_glacier_2xr", "deferred tool improvements"),
              (b"tengu_basalt_3kr", "MCP instruction delta"),
              (b"tengu_cobalt_frost", "voice conversation engine"),
              (b"tengu_scarf_coffee", "API context management"),
              (b"tengu_quartz_lantern", "remote tool use diff"),
              (b"tengu_marble_anvil", "thinking edits"),
              (b"tengu_marble_whisper2", "inline annotations"),
              (b"tengu_orchid_trellis", "plugin marketplace"),
              (b"tengu_pewter_gull", "PDF line limiting"),
              (b"tengu_moth_copse", "relevant memory recall"),
              (b"tengu_cork_m4q", "batch command processing"),
            ]

            flip_gates(core_gates + memory_gates + ux_gates + tool_gates)

            # --- Kill claude-developer-platform bundled skill (this uses ~400 tokens per turn, it's dead weight) ---

            data = data.replace(
              b'name:"claude-developer-platform",description:`',
              b'name:"claude-developer-platform",isEnabled:()=>!1,description:`',
            )
            log("killed claude-developer-platform skill")

            # --- Enrich context_window status line data ---

            ctx_pat: bytes = (
              rb"context_window:\{total_input_tokens:(" + W + rb"\(\)),"
              rb"total_output_tokens:(" + W + rb"\(\)),"
              rb"context_window_size:(" + W + rb"),"
              rb"current_usage:(" + W + rb"),"
              rb"used_percentage:(" + W + rb")\.used,"
              rb"remaining_percentage:\5\.remaining\}"
            )
            rl_pat: bytes = (
              rb"("
              + W
              + rb')=\{status:"allowed",unifiedRateLimitFallbackAvailable:!1,isUsingOverage:!1\}'
            )

            rl_match: re.Match[bytes] | None = re.search(rl_pat, data)
            ctx_match: re.Match[bytes] | None = re.search(ctx_pat, data)

            if ctx_match and rl_match:
              inp_tok, out_tok, win_size, usage, pct = [ctx_match.group(i) for i in range(1, 6)]
              rate_limit: bytes = rl_match.group(1)
              data = data.replace(
                ctx_match[0],
                b"context_window:{...(" + usage + b"||{}),"
                b"context_window_size:" + win_size + b",current_usage:" + usage + b","
                b"used_percentage:"
                + pct
                + b".used,remaining_percentage:"
                + pct
                + b".remaining,"
                b"rate_limit:" + rate_limit + b",s_in:" + inp_tok + b",s_out:" + out_tok + b"}",
              )
              log("context window statusline: patched")
            else:
              log(
                f"context window statusline: NOT FOUND (ctx={'yes' if ctx_match else 'no'}, rl={'yes' if rl_match else 'no'})"
              )

            # --- Cache oauth/usage to disk ---
            # Both /usage and the statusline need usage data but the API rate-limits hard.
            # We wrap the fetch function with a 60s file cache at /tmp/.claude-usage.json so
            # only one actual request goes out; everyone else reads the cache.

            usage_anchor: bytes = b"api/oauth/usage"
            usage_pos: int = data.find(usage_anchor)
            if usage_pos >= 0:
              # Find the enclosing "async function NAME(){" by scanning backwards
              fn_start: int = data.rfind(b"async function ", max(0, usage_pos - 500), usage_pos)
              if fn_start >= 0:
                # Find the function's closing brace by counting braces forward
                brace_depth: int = 0
                fn_end: int = fn_start
                for i in range(fn_start, min(len(data), usage_pos + 500)):
                  if data[i : i + 1] == b"{":
                    brace_depth += 1
                  elif data[i : i + 1] == b"}":
                    brace_depth -= 1
                    if brace_depth == 0:
                      fn_end = i + 1
                      break

                original_fn: bytes = data[fn_start:fn_end]
                # Extract function name from "async function NAME(){"
                fn_name_match = re.match(rb"async function (" + W + rb")\(\)\{", original_fn)
                if fn_name_match:
                  fn_name: bytes = fn_name_match.group(1)
                  # Rename original to _uc_ORIG, create caching wrapper with the original name
                  renamed: bytes = b"_uc_" + fn_name
                  patched_fn: bytes = (
                    b"async function "
                    + renamed
                    + original_fn[len(b"async function " + fn_name) :]
                    + b"async function "
                    + fn_name
                    + b'(){const _fs=require("fs"),'
                    b'_cp="/tmp/.claude-usage.json";'
                    b"try{const _s=_fs.statSync(_cp);"
                    b"if(Date.now()-_s.mtimeMs<60000)"
                    b'return JSON.parse(_fs.readFileSync(_cp,"utf8"))'
                    b"}catch{}"
                    b"const _r=await " + renamed + b"();"
                    b"try{_fs.writeFileSync(_cp,JSON.stringify(_r))}catch{}"
                    b"return _r}"
                  )
                  data = data[:fn_start] + patched_fn + data[fn_end:]
                  log("usage cache: patched")
                else:
                  log("usage cache: fn name not matched")
              else:
                log("usage cache: enclosing function not found")
            else:
              log("usage cache: NOT FOUND")

            Path(sys.argv[1]).write_bytes(data)
          '';
        in
        singleton
        <| pkgs.writeScriptBin "claude" /* nu */ ''
          #!${getExe pkgs.nushell}

          let cache_global = $env
          | get --optional "XDG_CACHE_HOME"
          | default ($env.HOME | path join ".cache")

          let cache = $cache_global | path join "claude-code"

          let version = do {
            let version_file = $cache | path join "latest-version"
            let ttl = 6hr

            match (try { (date now) - (ls $version_file | get 0.modified) > $ttl }) {
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

          let binary_path = if ($version | is-empty) {
            print --stderr $"(ansi yellow_bold)warn:(ansi reset) falling back to latest binary"

            try {
              glob ($cache)/claude-code-* | last
            } catch {
              print --stderr $"(ansi red_bold)error:(ansi reset) no binary found"
              exit 67
            }
          } else {
            $cache | path join $"claude-code-($version)"
          }

          if not ($binary_path | path exists) {
            ${getExe pkgs.deno} cache $"npm:@anthropic-ai/claude-code@($version)"
            ${getExe patch} ($cache_global | path join "deno" "npm" "registry.npmjs.org" "@anthropic-ai" "claude-code" $version "cli.js")
            ${getExe pkgs.deno} compile --allow-all --output $binary_path $"npm:@anthropic-ai/claude-code@($version)"
          }

          $env.PATH ++= [ "${pkgs.ripgrep}/bin" ]
          r#'${
            lib.strings.toJSON config.xdg.config.files."claude-code/settings.json".value.env
          }'# | from json | load-env

          exec $binary_path
        '';
    };
}
