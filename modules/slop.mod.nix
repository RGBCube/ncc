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
              rb"let (" + W + rb")=(" + W + rb")\((" + W + rb'),"CLAUDE\.md"\);'
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
              (b'name:"bridge-kick",description:"Inject bridge failure states', "/bridge-kick"),
              (b'name:"files",description:"List all files currently in context"', "/files"),
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

            # --- Bypass telemetry gate in feature flag checker ---
            # The chain is: h8(featureGate) bails to default if !Qo(); Qo()=Ew6();
            # Ew6()=!Cq6(); Cq6() returns true when on bedrock/vertex/foundry OR when
            # user-facing telemetry is disabled (s_1()/equivalent). Drop the trailing
            # telemetry-disabled check so feature gates still resolve with
            # DISABLE_TELEMETRY=1 while preserving the bedrock/vertex/foundry detection.
            # Anchor on the stable env-var literal CLAUDE_CODE_USE_BEDROCK; the obfuscated
            # function name (Cq6) and the trailing wrapper name (s_1) both rotate.

            patch(
              "telemetry gate (drop telemetry-disabled check)",
              (
                rb"function (" + W + rb")\(\)\{return F6\(process\.env\.CLAUDE_CODE_USE_BEDROCK\)"
                rb"\|\|F6\(process\.env\.CLAUDE_CODE_USE_VERTEX\)"
                rb"\|\|F6\(process\.env\.CLAUDE_CODE_USE_FOUNDRY\)"
                rb"\|\|" + W + rb"\(\)\}"
              ),
              lambda m: re.sub(rb"\|\|" + W + rb"\(\)\}$", b"||!1}", m[0]),
            )

            # --- Restore 1h prompt cache TTL when telemetry is off ---
            # https://github.com/anthropics/claude-code/issues/45381
            # maY() gates the "ttl":"1h" cache_control on a GrowthBook allowlist
            # (tengu_prompt_cache_1h_config). With telemetry off the lookup falls
            # through to the {} default, so .allowlist is undefined and the ??[]
            # fallback produces an empty array — every querySource fails the .some()
            # match and falls back to 5min TTL. Replace the empty fallback with ["*"]
            # so any defined querySource matches.

            patch(
              "1h prompt cache TTL fallback",
              rb'h8\("tengu_prompt_cache_1h_config",\{\}\)\.allowlist\?\?\[\]',
              b'h8("tengu_prompt_cache_1h_config",{}).allowlist??["*"]',
            )

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
              (b"tengu_ccr_bridge", "remote control"),
              (b"tengu_bridge_system_init", "bridge SDK init on connect"),
              (b"tengu_remote_backend", "remote backend"),
              (b"tengu_immediate_model_command", "instant /model switching"),
              (b"tengu_fgts", "fine-grained tool streaming"),
              (b"tengu_auto_background_agents", "background agent timeout"),
              (b"tengu_plan_mode_interview_phase", "plan mode interview"),
              (b"tengu_surreal_dali", "scheduled agents/cron"),
            ]

            memory_gates: list[Gate] = [
              # (b"tengu_session_memory", "session memory"),  # auto-memory; pollutes unrelated convos
              (b"tengu_pebble_leaf_prune", "message pruning"),
              (b"tengu_herring_clock", "team memory directory"),
              (b"tengu_passport_quail", "typed combined memory prompts"),
            ]

            ux_gates: list[Gate] = [
              (b"tengu_coral_fern", "grep hints in prompt"),
              (b"tengu_kairos_brief", "brief output mode"),
              (b"tengu_destructive_command_warning", "destructive command warnings"),
              (b"tengu_amber_prism", "permission denial context"),
              (b"tengu_hawthorn_steeple", "context windowing"),
            ]

            tool_gates: list[Gate] = [
              (b"tengu_chrome_auto_enable", "auto-enable chrome devtools"),
              (b"tengu_glacier_2xr", "deferred tool improvements"),
              (b"tengu_plum_vx3", "web search reranking"),
              # (b"tengu_moth_copse", "relevant memory recall"),  # auto-recall; pollutes unrelated convos
              (b"tengu_cork_m4q", "batch command processing"),
            ]

            flip_gates(core_gates + memory_gates + ux_gates + tool_gates)

            # --- Bump background agent timeout from 120s to 240s ---

            patch(
              "background agent timeout",
              rb'"tengu_auto_background_agents",![01]\)\)return 120000',
              lambda m: m[0].replace(b"120000", b"240000"),
            )

            # --- Replace usage fetch with self-contained OAuth implementation ---
            # FO()/eO() falls back to x-api-key when dA()/nA() returns false (telemetry off),
            # but /api/oauth/usage requires Bearer + oauth beta header. Replace the entire
            # function with a Deno-native implementation that reads credentials directly.

            usage_fn_pat: bytes = (
              rb"async function (" + W + rb")\(\)\{"
              rb"(?:if\(!" + W + rb"\(\)\|\|!" + W + rb"\(\)\)return\{\};)?"
              rb"let " + W + rb"=" + W + rb"\(\);if\(" + W + rb"&&" + W + rb"\(" + W + rb"\." + W + rb"\)\)return null;"
              rb"let " + W + rb"=" + W + rb"\(\);if\(" + W + rb"\.error\)throw Error\(\x60Auth error: \x24\{" + W + rb"\.error\}\x60\);"
              rb"let " + W + rb"=\{[^}]+\}," + W + rb"=\x60\x24\{(" + W + rb")\(\)\.(" + W + rb")\}/api/oauth/usage\x60;"
              rb"return\(await (" + W + rb")\.get\(" + W + rb",\{headers:" + W + rb",timeout:5000\}\)\)\.data\}"
            )

            usage_fn_match: re.Match[bytes] | None = re.search(usage_fn_pat, data)
            if usage_fn_match:
              fn_name: bytes = usage_fn_match.group(1)
              config_fn: bytes = usage_fn_match.group(2)
              base_url_key: bytes = usage_fn_match.group(3)
              http_client: bytes = usage_fn_match.group(4)
              replacement: bytes = (
                b"async function " + fn_name + b"(){"
                b"const _cd=(process.env.CLAUDE_CONFIG_DIR||"
                b'(Deno.env.get("HOME")+"/.config/claude"));'
                b"let _tk;"
                b'try{const _cr=JSON.parse(new TextDecoder().decode('
                b'Deno.readFileSync(_cd+"/.credentials.json")));'
                b"_tk=_cr?.claudeAiOauth?.accessToken}catch{return{}}"
                b"if(!_tk)return{};"
                b'const _cp="/tmp/.claude-usage-"+_tk.slice(-8)+".json";'
                b"try{const _s=Deno.statSync(_cp);"
                b"if(Date.now()-_s.mtime.getTime()<60000)"
                b'return JSON.parse(new TextDecoder().decode(Deno.readFileSync(_cp)))}catch{}'
                b"const _h={" + b'"Content-Type":"application/json",'
                b'"Authorization":"Bearer "+_tk,'
                b'"anthropic-beta":"oauth-2025-04-20"};'
                b"const _u=`''${" + config_fn + b"()." + base_url_key + b"}/api/oauth/usage`;"
                b"const _r=(await " + http_client + b".get(_u,{headers:_h,timeout:5000})).data;"
                b'try{Deno.writeTextFileSync(_cp,JSON.stringify(_r))}catch{}'
                b"return _r}"
              )
              data = data.replace(usage_fn_match[0], replacement)
              log("usage fetch: replaced")
            else:
              log("usage fetch: pattern NOT FOUND")

            Path(sys.argv[1]).write_bytes(data)
          '';
        in
        singleton
        <| pkgs.writeScriptBin "claude" /* nu */ ''
          #!${getExe pkgs.nushell}

          def --wrapped main [--rebuild, ...arguments] {
            let cache_global = $env
            | get --optional "XDG_CACHE_HOME"
            | default ($env.HOME | path join ".cache")

            let cache = $cache_global | path join "claude-code"

            let version = do {
              let version_file = $cache | path join "latest-version"

              match (try { (date now) - (ls $version_file | get 0.modified) > 6hr }) {
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

            if not ($binary_path | path exists) or $rebuild {
              ${getExe pkgs.deno} cache $"npm:@anthropic-ai/claude-code@($version)"
              ${getExe patch} ($cache_global | path join "deno" "npm" "registry.npmjs.org" "@anthropic-ai" "claude-code" $version "cli.js")
              ${getExe pkgs.deno} compile --allow-all --output $binary_path $"npm:@anthropic-ai/claude-code@($version)"
            }

            $env.PATH ++= [ "${pkgs.ripgrep}/bin" ]
            r#'${
              lib.strings.toJSON config.xdg.config.files."claude-code/settings.json".value.env
            }'# | from json | load-env

            exec $binary_path ...$arguments
          }
        '';
    };
}
