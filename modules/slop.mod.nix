{ self, lib, ... }:
let
  inherit (lib.attrsets) getAttr;
  inherit (lib.lists) concatMap singleton;
  inherit (lib.strings) concatLines makeBinPath;

  mkNixs = pkgs: self.packages.${pkgs.stdenv.hostPlatform.system}.nixs;

  mkExtraPath =
    pkgs: package:
    pkgs.symlinkJoin {
      inherit (package) name;

      paths = singleton package;
      nativeBuildInputs = singleton pkgs.makeWrapper;

      postBuild = /* bash */ ''
        for binary in $out/bin/*; do
          wrapProgram "$binary" --suffix PATH : ${
            makeBinPath [
              pkgs.gnused
              pkgs.gawk
              pkgs.jq
              pkgs.gnutar
              pkgs.gzip
              pkgs.ugrep
              pkgs.bfs
              pkgs.ripgrep
            ]
          }
        done
      '';
    };

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
        (mkExtraPath pkgs pkgs.opencode)
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
        (mkExtraPath pkgs pkgs.codex)
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
      inherit (lib.meta) getExe;

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
          let root_result = do { jj --ignore-working-copy root } | complete
          if $root_result.exit_code != 0 { return "" }

          # --ignore-working-copy so a killed render can't leave the working
          # copy stale; the watchman snapshot trigger keeps the data fresh.
          let bookmark = (do { jj --ignore-working-copy log -r @ --no-graph -T 'bookmarks.map(|b| b.name()).join(", ")' } | complete | get stdout | str trim)
          let change = (do { jj --ignore-working-copy log -r @ --no-graph -T 'change_id.shortest(8)' } | complete | get stdout | str trim)
          let is_empty_str = (do { jj --ignore-working-copy log -r @ --no-graph -T 'empty' } | complete | get stdout | str trim)
          let dirty = if $is_empty_str == "false" { "*" } else { "" }
          let has_conflict = (do { jj --ignore-working-copy log -r @ --no-graph -T 'conflict' } | complete | get stdout | str trim)
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

            # Unpack the module graph from a bun --compile --bytecode executable.
            #
            # Starting with @anthropic-ai/claude-code 2.1.113 the npm package stopped
            # shipping cli.js and instead publishes platform-specific tarballs that contain
            # a bun-compiled executable. The JavaScript is still fully embedded as
            # plaintext — the @bytecode marker just means a V8 parse-cache lives alongside
            # it, not instead of it.
            #
            # Up to 2.1.235 the payload held one big `@bun-cjs` module (the whole bundle),
            # which we lifted to a single cli.cjs. 2.1.245 switched to a code-split ESM
            # build: ~1400 modules — an extensionless entry point, `chunk-<hash>.js`
            # chunks, a worker under `src/`, four assets (mermaid, chart.js, highlight.js,
            # an HTML template) and the optional native `.node` addons. So we unpack the
            # whole graph into a directory instead.
            #
            # Bun stores that graph in a dedicated section (Mach-O `__BUN,__bun`, ELF
            # `.bun`) laid out as:
            #   u64 payload_byte_count
            #   <payload: every module name, source, bytecode and sourcemap concatenated>
            #   Offsets struct
            #   "\n---- Bun! ----\n"
            # Every pointer into the payload is a StringPointer {u32 offset, u32 length}
            # relative to the start of the payload, i.e. 8 bytes into the section. The
            # module table is an array of 52-byte entries; we need three of its fields:
            # the module name, the source text, and the kind (JS / asset / native addon).

            import posixpath
            import re
            import struct
            import sys
            from pathlib import Path

            TRAILER: bytes = b"\n---- Bun! ----\n"

            # Every module is named /$bunfs/root/<path>; bun resolves imports against that
            # virtual root, so the tree we unpack mirrors it.
            ROOT: str = "/$bunfs/root/"

            KIND_JS: int = 0x10101

            STRIDE: int = 52

            # The entry point is extensionless (`/$bunfs/root/cli`), which Deno won't
            # resolve as a module. Give it a name of our own.
            ENTRY: str = "cli.js"

            # Matching the launcher that runs us: `ansi blue_bold` and `ansi red_bold`.
            INFO: str = "\x1b[1;34minfo:\x1b[0m"
            ERROR: str = "\x1b[1;31merror:\x1b[0m"


            def info(message: str) -> None:
              sys.stderr.write(f"{INFO} {message}\n")


            def die(message: str) -> None:
              sys.exit(f"{ERROR} {message}")


            def find_bun_section(data: bytes) -> tuple[int, int]:
              """Return the (offset, size) of the section holding bun's module graph."""
              if data[:4] in (b"\xcf\xfa\xed\xfe", b"\xce\xfa\xed\xfe"):
                ncmds: int = struct.unpack_from("<I", data, 16)[0]
                pos: int = 32
                for _ in range(ncmds):
                  cmd, cmdsize = struct.unpack_from("<II", data, pos)
                  if cmd == 0x19 and data[pos + 8 : pos + 24].rstrip(b"\0") == b"__BUN":
                    nsects: int = struct.unpack_from("<I", data, pos + 64)[0]
                    spos: int = pos + 72
                    for _ in range(nsects):
                      if data[spos : spos + 16].rstrip(b"\0") == b"__bun":
                        size: int = struct.unpack_from("<Q", data, spos + 40)[0]
                        return struct.unpack_from("<I", data, spos + 48)[0], size
                      spos += 80
                  pos += cmdsize
                die("Mach-O has no __BUN,__bun section")

              if data[:4] == b"\x7fELF":
                shoff: int = struct.unpack_from("<Q", data, 0x28)[0]
                shentsize, shnum, shstrndx = struct.unpack_from("<HHH", data, 0x3A)
                strtab: int = struct.unpack_from(
                  "<Q", data, shoff + shstrndx * shentsize + 0x18
                )[0]
                for i in range(shnum):
                  base: int = shoff + i * shentsize
                  name_off: int = struct.unpack_from("<I", data, base)[0]
                  name: bytes = data[strtab + name_off : data.index(b"\0", strtab + name_off)]
                  if name == b".bun":
                    return struct.unpack_from("<QQ", data, base + 0x18)
                die("ELF has no .bun section")

              die("unrecognised executable container")


            def parse_graph(data: bytes) -> tuple[list[tuple[str, bytes, int]], int]:
              """Return every (name, source, kind) in the graph, and the entry's index."""
              offset, size = find_bun_section(data)
              section: bytes = data[offset : offset + size]
              if not section.endswith(TRAILER):
                die("section does not end with the bun trailer")

              payload: bytes = section[8:]

              # Counting back from the trailer, the Offsets struct ends with the module
              # table's StringPointer at -24 and the entry point's index at -16.
              table_offset, table_length, entry_id = struct.unpack(
                "<III", section[-len(TRAILER) - 24 : -len(TRAILER) - 12]
              )

              count, remainder = divmod(table_length, STRIDE)
              if remainder:
                die(f"module table is not a multiple of {STRIDE} bytes")
              if not 0 <= entry_id < count:
                die(f"entry point index {entry_id} is outside the module table")

              table: bytes = payload[table_offset : table_offset + table_length]
              modules: list[tuple[str, bytes, int]] = []
              for i in range(count):
                fields = struct.unpack_from(f"<{STRIDE // 4}I", table, i * STRIDE)
                name: str = payload[fields[0] : fields[0] + fields[1]].decode()
                source: bytes = payload[fields[2] : fields[2] + fields[3]]
                modules.append((name, source, fields[12]))

              return modules, entry_id


            def rewrite(source: bytes, origin: str, paths: dict[str, str]) -> bytes:
              """Repoint bunfs references at the unpacked tree.

              Import specifiers become paths relative to the importing module, so Deno
              walks the graph the way bun did. That includes `import(...)`, which the
              bundle uses for around a thousand lazily-loaded chunks: the specifier has to
              stay a literal, because a computed one is invisible to `deno compile` and
              the chunk would be missing from the binary. Every other bunfs string is a
              path read at runtime — an asset, a native addon, a worker — and becomes an
              `import.meta.dirname` expression, which resolves inside a compiled binary
              just as it does on disk.
              """
              here: str = posixpath.dirname(origin)

              def relative(target: str) -> str:
                path: str = posixpath.relpath(paths[ROOT + target], here)
                return path if path.startswith(".") else "./" + path

              def as_specifier(match: re.Match[bytes]) -> bytes:
                return match[1] + b'"' + relative(match[2].decode()).encode() + b'"'

              def as_runtime_path(match: re.Match[bytes]) -> bytes:
                return b'(import.meta.dirname+"/' + relative(match[1].decode()).encode() + b'")'

              root: bytes = re.escape(ROOT.encode())
              specifier: bytes = rb'((?<![\w$.])(?:from|import)\s*\(?\s*)"' + root + rb'([^"]+)"'
              source = re.sub(specifier, as_specifier, source)
              return re.sub(rb'"' + root + rb'([^"]+)"', as_runtime_path, source)


            def main() -> None:
              if len(sys.argv) != 3:
                die("usage: lift-claude-bun <claude-binary> <output-directory>")

              binary = Path(sys.argv[1])
              outdir = Path(sys.argv[2])

              modules, entry_id = parse_graph(binary.read_bytes())

              paths: dict[str, str] = {}
              for i, (name, _, _) in enumerate(modules):
                if not name.startswith(ROOT):
                  die(f"module lives outside {ROOT}: {name}")
                paths[name] = ENTRY if i == entry_id else name[len(ROOT) :]

              # Sanity: the real claude-code entry point always carries this legal banner.
              if b"Anthropic" not in modules[entry_id][1][:4096]:
                die("entry point is missing the Anthropic banner — layout changed?")

              for name, source, kind in modules:
                path: str = paths[name]
                if kind == KIND_JS:
                  source = rewrite(source, path, paths)
                target = outdir / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(source)

              js: int = sum(1 for _, _, kind in modules if kind == KIND_JS)
              info(
                f"lifted {len(modules)} modules ({js} JS, {len(modules) - js} assets) "
                f"from {binary.name} -> {outdir}"
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

            SEARCH_WINDOW: int = 500

            # The entry point `lift` writes, and the Bun polyfill module we add beside it.
            ENTRY: str = "cli.js"
            SHIM: str = "bun-polyfill.js"

            # Since 2.1.245 the bundle is code-split across ~1400 ESM modules rather than
            # one CJS blob, so every pass runs over the whole tree. Each module carries
            # bun's banner; assets (mermaid, chart.js, highlight.js, the HTML template)
            # and native addons sit in the same tree and must not be touched.
            BANNER: bytes = b"// @bun"

            # Matching the launcher that runs us: `ansi blue_bold` and friends.
            INFO: str = "\x1b[1;34minfo:\x1b[0m"
            WARN: str = "\x1b[1;33mwarn:\x1b[0m"
            ERROR: str = "\x1b[1;31merror:\x1b[0m"


            def die(message: str) -> None:
              sys.exit(f"{ERROR} {message}")


            tree: Path = Path(sys.argv[1])
            modules: dict[Path, bytes] = {}
            for path in sorted(tree.rglob("*.js")):
              source: bytes = path.read_bytes()
              if source.startswith(BANNER):
                modules[path] = source

            if not modules:
              die(f"no bun modules under {tree}")


            def info(message: str) -> None:
              sys.stderr.write(f"{INFO} {message}\n")


            def warn(message: str) -> None:
              sys.stderr.write(f"{WARN} {message}\n")


            def patch(label: str, pattern: bytes, replacement: Replacement) -> None:
              total: int = 0
              for path, source in modules.items():
                modules[path], n = re.subn(pattern, replacement, source)
                total += n
              info(f"{label} ({total})")


            def replace(label: str, old: bytes, new: bytes) -> None:
              total: int = 0
              for path, source in modules.items():
                n: int = source.count(old)
                if n:
                  modules[path] = source.replace(old, new)
                  total += n
              if total == 0:
                warn(f"{label}: NOT FOUND")
                return
              info(f"{label} ({total})")


            def flip_gates(gates: list[tuple[bytes, str]]) -> None:
              """Flip all gate defaults from false to true in a single regex pass."""
              gate_keys: list[bytes] = [g for g, _ in gates]
              labels: dict[bytes, str] = dict(gates)
              alternation: bytes = b"|".join(re.escape(g) for g in gate_keys)
              pat: bytes = W + rb'\("(' + alternation + rb')",!1\)'
              flipped: set[bytes] = set()
              total: int = 0

              def replacer(m: re.Match[bytes]) -> bytes:
                flipped.add(m.group(1))
                return m[0].replace(b",!1)", b",!0)")

              for path, source in modules.items():
                modules[path], n = re.subn(pat, replacer, source)
                total += n

              info(f"feature gates: {total} flipped across {len(flipped)} gates")
              for key in gate_keys:
                if key in flipped:
                  info(f"feature gate {labels[key]} [ok]")
                else:
                  # Upstream renames and retires gates constantly. A gate that matched
                  # nothing is already a no-op in the build, so this is a prune, not a
                  # breakage — see the maintenance note in the module.
                  warn(f"feature gate {labels[key]} [MISSED]")


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
              for path, source in modules.items():
                pos: int = source.find(anchor)
                if pos < 0:
                  continue
                window: bytes = source[pos : pos + SEARCH_WINDOW]
                patched: bytes = window.replace(b"isEnabled:()=>!1", b"isEnabled:()=>!0", 1)
                if patched == window:
                  warn(f"slash command {label}: isEnabled not found in window")
                  break
                modules[path] = source[:pos] + patched + source[pos + SEARCH_WINDOW :]
                info(f"slash command {label}: enabled")
                break
              else:
                warn(f"slash command {label}: NOT FOUND")

            # --- Force the async feature-gate resolver to resolve true when offline ---
            # The ASYNC gate resolver falls back to its default when telemetry is off, so
            # every gate it resolves reads false. In 2.1.245 it is a method,
            # `checkGateCachedOrBlocking`, and the bail is `if(!this.deps.isEnabled())`.
            # A SIBLING method (`isFeatureFromExperiment`) opens with the very same bail,
            # so we anchor on the line that follows it in the resolver we want; the
            # explicit environment/config override maps it checks first stay untouched,
            # so an intentionally-disabled gate stays disabled.
            #
            # Every gate reaching this resolver is one we want enabled — bridge
            # auto-connect (tengu_ccr_bridge), the CCR bundle seed, the plugin marketplace
            # (tengu_harbor, tengu_bubbly_harbor) — and none of them is a `tengu_disable_*`
            # or a killswitch, where forcing true would turn a good behaviour OFF.

            replace(
              "async gate offline fallback true",
              b"if(!this.deps.isEnabled())return!1;if(this.remoteEvalFeatureValues.get(e)===!0)",
              b"if(!this.deps.isEnabled())return!0;if(this.remoteEvalFeatureValues.get(e)===!0)",
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
              (b"tengu_fgts", "fine-grained tool streaming"),
              (b"tengu_surreal_dali", "scheduled agents/cron"),
            ]

            memory_gates: list[Gate] = [
              # (b"tengu_session_memory", "session memory"),  # auto-memory; pollutes unrelated convos
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

            # --- grep/find/rg shim: delegate to PATH ---
            # claude-code ships a shell shim factory that emits bash functions
            # which redefine `grep`/`find`/`rg` to re-exec the claude binary
            # with argv[0]=ugrep/bfs/rg. In Bun "ant-native" builds this
            # dispatches to bundled native tools. The Deno repack drops those,
            # so invocations fail with `error: unknown option '-G'`. Replace the
            # factory's body so it emits bash that calls the real tools by name;
            # `withExtraPath` puts ugrep/bfs/rg on the wrapper's PATH.
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
            # single-line bash function that runs the real tool via `command`
            # (which bypasses the shim function itself when the names collide,
            # as they do for rg).

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
              die("grep/find/rg shim: unbalanced braces")


            fzr_sig: bytes = (
              rb"function (" + W + rb")\((" + W + rb"),(" + W + rb"),("
              + W + rb")=\[\],(" + W + rb")=\[\]\)\{"
            )
            # The same four-parameter signature occurs in bundled third-party code (and in
            # the mermaid asset), so the emitted bash header is what identifies the factory.
            for path, source in modules.items():
              fzr_match: re.Match[bytes] | None = None
              for cand in re.finditer(fzr_sig, source):
                if b"\x60function ''${" + cand.group(2) + b"} {" in source[cand.end():cand.end() + 800]:
                  fzr_match = cand
                  break

              if fzr_match is None:
                continue

              fn_name: bytes = fzr_match.group(1)
              body_end: int = scan_js_block(source, fzr_match.end())
              fzr_new: bytes = (
                b"function " + fn_name + b"(e,t,n=[],r=[]){"
                b'let o=n.length>0?n.join(" ")+\' "$@"\':\'"$@"\';'
                b'return "function "+e+" { command "+t+" "+o+"; }"}'
              )
              modules[path] = source[:fzr_match.start()] + fzr_new + source[body_end:]
              info(f"grep/find/rg shim: replaced {fn_name.decode()} in {path.name}")
              break
            else:
              warn("grep/find/rg shim: NOT FOUND")

            # --- Bundle require (native addons + text assets) ---
            # The bundle's runtime `require` is `import.meta.require`, a bun-only API
            # that is undefined under Deno. It loads two kinds of modules: native
            # `.node` addons, and (since 2.1.246) `.md`/`.txt` assets that bun's text
            # loader resolves to their file contents — the /loop autonomous preambles
            # (required at startup) and the bundled skill bodies. `createRequire`
            # covers the addons, but parses a required `.md` as JavaScript and throws
            # a SyntaxError before the REPL starts. Swap in a wrapper (defined by the
            # polyfill module below, which evaluates first) that reads text assets off
            # disk and defers to `createRequire` for everything else.

            patch(
              "bundle require (addons + text assets)",
              rb"import\.meta\.require",
              b"globalThis.__bunRequire(import.meta.url)",
            )

            # --- Bun runtime polyfill ---
            # Since 2.1.128 the bundle calls Bun.* APIs unguarded (Bun.stringWidth,
            # Bun.semver, Bun.hash, Bun.spawn, Bun.YAML, Bun.TOML, Bun.deepEquals,
            # Bun.connect, Bun.Transpiler, Bun.listen, Bun.which, Bun.wrapAnsi,
            # Bun.stripANSI, Bun.embeddedFiles, Bun.gc, Bun.generateHeapSnapshot,
            # Bun.JSONL, Bun.Terminal, Bun.ant, Bun.version). Under Deno these throw
            # `ReferenceError: Bun is not defined` at first use (Bun.stringWidth fires in
            # a column-width helper during banner render). Define globalThis.Bun upfront
            # with Node-backed equivalents so bare `Bun.X` lookups resolve.
            #
            # Bun.Terminal, Bun.JSONL and Bun.ant are intentionally left absent: the
            # bundle already has fallback paths gated on `typeof Bun.Terminal<"u"` and
            # `Bun.JSONL?.parseChunk`, and every Bun.ant call (memory pressure, peer
            # credentials) sits inside a try/catch that degrades cleanly. Leaving them
            # undefined preserves the built-in "not running under bun" degradation rather
            # than half-emulating it.
            #
            # The bundle is ESM now, so this is a module of its own rather than a prelude
            # prepended to a CJS blob. ESM evaluates a module's imports before its body,
            # depth first and in source order, so importing it on the entry point's first
            # line means globalThis.Bun and globalThis.__bunRequire exist before any
            # chunk's top-level code runs.

            bun_shim: bytes = rb"""import sw from "string-width";
            import sa from "strip-ansi";
            import wa from "wrap-ansi";
            import sv from "semver";
            import * as ya from "yaml";
            import * as tm from "smol-toml";
            import cp from "node:child_process";
            import fs from "node:fs";
            import path from "node:path";
            import crypto from "node:crypto";
            import net from "node:net";
            import util from "node:util";
            import{createRequire}from "node:module";
            globalThis.__bunRequire=(url)=>{const req=createRequire(url);const f=(spec)=>/\.(md|txt)$/.test(String(spec))?fs.readFileSync(spec,"utf8"):req(spec);return Object.assign(f,req);};
            function bunHash(input){const buf=Buffer.isBuffer(input)?input:Buffer.from(typeof input==="string"?input:String(input));return crypto.createHash("sha1").update(buf).digest().readBigUInt64LE(0);}
            function bunSpawn(cmd,opts){opts=opts||{};const[bin,...args]=cmd;const stdio=["pipe","pipe",opts.stderr==="ignore"?"ignore":"pipe"];const child=cp.spawn(bin,args,{cwd:opts.cwd,env:opts.env||process.env,stdio,argv0:opts.argv0});const exited=new Promise(r=>child.on("exit",c=>r(c==null?1:c)));return{pid:child.pid,stdin:child.stdin,stdout:child.stdout,stderr:child.stderr,exitCode:null,killed:false,kill(s){try{child.kill(s)}catch{}this.killed=true},async wait(){return await exited},exited};}
            function bunListen(opts){const h=opts.socket||{};const server=net.createServer(s=>{if(h.open)try{h.open(s)}catch{}s.on("data",d=>h.data&&h.data(s,d));s.on("close",()=>h.close&&h.close(s));s.on("error",e=>h.error&&h.error(s,e));});server.listen(opts.port||0,opts.hostname||"127.0.0.1");return server;}
            function bunConnect(opts){const h=opts.socket||{};const s=net.connect({host:opts.hostname,port:opts.port});if(h.open)s.on("connect",()=>h.open(s));s.on("data",d=>h.data&&h.data(s,d));s.on("close",()=>h.close&&h.close(s));s.on("error",e=>h.error&&h.error(s,e));return Promise.resolve(s);}
            class BunTranspiler{constructor(o){this.opts=o}transformSync(s){return s}}
            globalThis.Bun={version:"1.3.13",embeddedFiles:[],stringWidth:(s,o)=>sw(String(s||""),o),stripANSI:s=>sa(String(s||"")),wrapAnsi:(s,w,o)=>wa(String(s||""),w,o),semver:{satisfies:(a,b)=>sv.satisfies(a,b),order:(a,b)=>sv.compare(a,b)},hash:bunHash,deepEquals:(a,b)=>util.isDeepStrictEqual(a,b),which(cmd){const dirs=(process.env.PATH||"").split(path.delimiter);for(const d of dirs){const f=path.join(d,cmd);try{fs.accessSync(f,fs.constants.X_OK);return f;}catch{}}return null;},spawn:bunSpawn,listen:bunListen,connect:bunConnect,YAML:{parse:s=>ya.parse(s),stringify:(o,r,i)=>ya.stringify(o,r,i)},TOML:{parse:s=>tm.parse(s)},Transpiler:BunTranspiler,generateHeapSnapshot:()=>new ArrayBuffer(0),gc:()=>{}};
            """

            (tree / SHIM).write_bytes(bun_shim)

            entry: Path = tree / ENTRY
            if entry not in modules:
              die(f"no entry point at {entry}")
            modules[entry] = b'import"./' + SHIM.encode() + b'";' + modules[entry]
            info("Bun runtime polyfill: imported by the entry point")

            for path, source in modules.items():
              path.write_bytes(source)
          '';
        in
        [
          (
            mkExtraPath pkgs
            <| pkgs.writers.writeNuBin "claude" /* nu */ ''
              def detect-platform []: nothing -> string {
                let arch = match ($nu.os-info.arch | str lowercase) {
                  "x86_64" | "x64" | "amd64" => "x64"
                  "aarch64" | "arm64" => "arm64"
                  $arch => {
                    print --stderr $"(ansi red_bold)error:(ansi reset) unsupported arch: ($arch)"
                    exit 67
                  }
                }

                match ($nu.os-info.name | str lowercase) {
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
                  | where { not ($"($in.name).failed" | path exists) }
                  | sort-by modified
                  | last
                  | get name

                  print --stderr $"(ansi blue_bold)info:(ansi reset) running ($latest | path basename)"
                  exec $latest ...$arguments
                } catch {
                  print --stderr $"(ansi red_bold)error:(ansi reset) no binary found"
                  exit 67
                }
              }

              def build [--workdir: directory, --into: path] {
                let tree = $workdir | path join "tree"
                let entrypoint = $tree | path join "cli.js"

                ^${getExe lift} ($workdir | path join "package" "claude") $tree
                ^${getExe patch} $tree

                r###'${
                  strings.toJSON {
                    name = "claude-code-lifted";
                    type = "module";
                    dependencies = {
                      ws = "^8";
                      undici = "^6";
                      node-fetch = "^3";
                      ajv = "^8";
                      ajv-formats = "^3";
                      yaml = "^2";
                      # Bun shim deps (see "Bun runtime polyfill" in patch script).
                      smol-toml = "^1";
                      string-width = "^7";
                      strip-ansi = "^7";
                      wrap-ansi = "^9";
                      semver = "^7";
                    };
                  }
                }'###
                | save --force ($tree | path join "package.json")

                do {
                  cd $tree

                  print --stderr $"(ansi blue_bold)info:(ansi reset) installing dependencies"
                  (^${getExe pkgs.deno} install
                    --quiet
                    --node-modules-dir=auto
                    --entrypoint $entrypoint)

                  print --stderr $"(ansi blue_bold)info:(ansi reset) compiling, hold on"
                  (^${getExe pkgs.deno} compile
                    --quiet
                    --allow-all
                    --node-modules-dir=auto
                    --include $tree
                    --output $into
                    $entrypoint)
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
                let binary_path_failed = $"($binary_path).failed"

                let workdir = $cache | path join $"claude-code-($version)-workdir"

                let archive_path = $"($binary_path).tar.gz"

                if ($binary_path_failed | path exists) and not $rebuild {
                  print --stderr $"(ansi yellow_bold)warn:(ansi reset) failed to build ($version) previously, pass --rebuild to retry"
                  run-latest --cache $cache ...$arguments
                }

                if not ($binary_path | path exists) or $rebuild {
                  # ARCHIVE
                  if not ($archive_path | path exists) {
                    let platform = detect-platform

                    try {
                      print --stderr $"(ansi blue_bold)info:(ansi reset) downloading tarball"
                      http get --raw $"https://registry.npmjs.org/@anthropic-ai/claude-code-($platform)/-/claude-code-($platform)-($version).tgz"
                      | save --force --raw $archive_path
                      print --stderr $"(ansi blue_bold)info:(ansi reset) downloaded (ls $archive_path | get 0.size)"
                    } catch {
                      print --stderr $"(ansi yellow_bold)warn:(ansi reset) failed to download tarball"
                      rm --force $archive_path
                      run-latest --cache $cache ...$arguments
                    }
                  }

                  # WORKDIR WITH EXTRACTED ARCHIVE
                  do {
                    rm --recursive --force $workdir

                    mkdir $workdir

                    try {
                      print --stderr $"(ansi blue_bold)info:(ansi reset) extracting tarball"
                      ^${getExe pkgs.gnutar} --extract --use-compress-program ${getExe pkgs.gzip} --file $archive_path --directory $workdir
                    } catch {
                      rm --force $archive_path

                      print --stderr $"(ansi yellow_bold)warn:(ansi reset) failed to extract tarball"
                      run-latest --cache $cache ...$arguments
                    }
                  }

                  # BUILD
                  do {
                    rm --force $binary_path

                    try {
                      print --stderr $"(ansi blue_bold)info:(ansi reset) building ($version)"
                      build --workdir $workdir --into $binary_path
                    } catch { |error|
                      touch $binary_path_failed

                      print --stderr $"(ansi yellow_bold)warn:(ansi reset) failed to build ($version): ($error.msg)"
                      run-latest --cache $cache ...$arguments
                    }
                  }
                }

                rm --force $binary_path_failed
                rm --recursive --force $workdir
                rm --force $archive_path

                exec $binary_path ...$arguments
              }
            ''
          )

          (mkNixs pkgs)
        ];
    };
}
