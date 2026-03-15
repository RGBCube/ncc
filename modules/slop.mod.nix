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
    in
    {
      xdg.config.files."claude-code/settings.json".generator = toJSON { };
      xdg.config.files."claude-code/settings.json".value = {
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

        enabledPlugins."code-simplifier@claude-plugins-official" = true;
        enabledPlugins."rust-analyzer-lsp@claude-plugins-official" = true;

        env.USE_BUILTIN_RIPGREP = "0";
        env.DISABLE_AUTOUPDATER = "1";
        env.DISABLE_INSTALLATION_CHECKS = "1";
      };

      packages =
        let
          # This is 100% slop but it doesn't matter.
          patch = pkgs.writeScriptBin "patch-claude-code-src" /* py */ ''
            #!${getExe pkgs.python3}
            import re, sys
            W = rb"[\w$]+"
            data = open(sys.argv[1], "rb").read()

            pat = (rb"let (" + W + rb")=(" + W + rb")\((" + W + rb'),"CLAUDE\.md"\);'
                   rb"(" + W + rb")\.push\(\.\.\.(" + W + rb')\(\1,"Project",([^)]+)\)\)')
            def agents(m):
                v, pj, d, a, lf, rest = [m.group(i) for i in range(1, 7)]
                return (b'for(let _f of["CLAUDE.md","AGENTS.md"]){let ' + v + b"=" + pj
                        + b"(" + d + b",_f);" + a + b".push(..." + lf + b"(" + v
                        + b',"Project",' + rest + b"))}")
            data, n = re.subn(pat, agents, data)
            sys.stderr.write(f"AGENTS.md: {n} site(s)\n")

            data = data.replace(
                b'case"macos":return"/Library/Application Support/ClaudeCode"',
                b'case"macos":return"/etc/claude-code"',
            )

            # Enable hard-disabled slash commands: /btw, /files, /tag
            for anchor, label in [
                (b'name:"btw",description:"Ask a quick side question', b"/btw"),
                (b'name:"files",description:"List all files currently in context"', b"/files"),
                (b'name:"tag",userFacingName', b"/tag"),
            ]:
                pos = data.find(anchor)
                if pos < 0:
                    sys.stderr.write(f"{label.decode()}: NOT FOUND\n"); continue
                window = data[pos:pos+500]
                patched = window.replace(b"isEnabled:()=>!1", b"isEnabled:()=>!0", 1)
                data = data[:pos] + patched + data[pos+500:]
                sys.stderr.write(f"{label.decode()}: enabled\n")

            # Bypass gate fn for thinkback (gate fn returns false when DISABLE_TELEMETRY is set)
            data, n = re.subn(
                W + rb'\("tengu_thinkback"\)',
                b'!0||"tengu_thinkback"',
                data,
            )
            sys.stderr.write(f"thinkback: {n} site(s)\n")

            # Enable custom keybindings (gate fn default is false, flip to true)
            data, n = re.subn(
                W + rb'\("tengu_keybinding_customization_release",!1\)',
                lambda m: m[0].replace(b",!1)", b",!0)"),
                data,
            )
            sys.stderr.write(f"keybindings: {n} site(s)\n")

            # Force-enable remote control / bridge feature gate
            data, n = re.subn(
                rb"function (" + W + rb")\(\)\{return " + W + rb'\("tengu_ccr_bridge",!1\)\}',
                lambda m: b"function " + m.group(1) + b"(){return!0}",
                data,
            )
            sys.stderr.write(f"remote-control: {n} site(s)\n")

            # Also bypass async remote control gate (server-side flag check)
            data, n = re.subn(
                rb"async function (" + W + rb")\(\)\{return " + W + rb'\("tengu_ccr_bridge"\)\}',
                lambda m: b"async function " + m.group(1) + b"(){return!0}",
                data,
            )
            sys.stderr.write(f"remote-control-async: {n} site(s)\n")

            # Fix Deno-compile bridge spawn: Deno compiled binaries intercept --flags
            # as V8 flags. Rewrite spawn to go through env(1) which breaks the Deno
            # runtime's flag parsing.
            data, n = re.subn(
                rb"let (" + W + rb")=(" + W + rb")\((" + W + rb")\.execPath,(" + W + rb"),",
                lambda m: b"let " + m[1] + b"=" + m[2] + b'("env",["--",' + m[3] + b".execPath,..." + m[4] + b"],",
                data,
            )
            sys.stderr.write(f"bridge-spawn: {n} site(s)\n")

            # Enable streaming text display (token-by-token instead of waiting for blocks)
            for gate in [b"tengu_streaming_text", b"tengu_immediate_model_command", b"tengu_fgts"]:
                pat = W + rb'\("' + gate + rb'",!1\)'
                data, n = re.subn(pat, lambda m, g=gate: m[0].replace(b",!1)", b",!0)"), data)
                sys.stderr.write(f"{gate.decode()}: {n} site(s)\n")

            # Kill claude-developer-platform bundled skill (~400 tokens/turn dead weight)
            data = data.replace(
                b'name:"claude-developer-platform",description:`',
                b'name:"claude-developer-platform",isEnabled:()=>!1,description:`',
            )
            sys.stderr.write("claude-developer-platform: killed\n")

            pat = (rb"context_window:\{total_input_tokens:(" + W + rb"\(\)),"
                   rb"total_output_tokens:(" + W + rb"\(\)),"
                   rb"context_window_size:(" + W + rb"),"
                   rb"current_usage:(" + W + rb"),"
                   rb"used_percentage:(" + W + rb")\.used,"
                   rb"remaining_percentage:\5\.remaining\}")
            rl = re.search(rb"(" + W + rb')=\{status:"allowed",unifiedRateLimitFallbackAvailable:!1,isUsingOverage:!1\}', data)
            m = re.search(pat, data)
            if m and rl:
                ci, co, sz, u, p, r = *[m.group(i) for i in range(1, 6)], rl.group(1)
                data = data.replace(m[0],
                    b"context_window:{...(" + u + b"||{}),"
                    b"context_window_size:" + sz + b",current_usage:" + u + b","
                    b"used_percentage:" + p + b".used,remaining_percentage:" + p + b".remaining,"
                    b"rate_limit:" + r + b",s_in:" + ci + b",s_out:" + co + b"}")

            open(sys.argv[1], "wb").write(data)
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
