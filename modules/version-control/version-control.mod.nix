{ self, config, ... }:
{
  flake.homeModules.version-control.imports = [
    self.homeModules.difftastic
    self.homeModules.gh
    self.homeModules.git
    self.homeModules.jujutsu
    self.homeModules.mergiraf
    self.homeModules.radicle
    self.homeModules.watchman
  ];

  flake.homeModules.gh =
    { lib, pkgs, ... }:
    let
      inherit (lib.generators) toGitINI toYAML;
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkDefault;
    in
    {
      packages = singleton pkgs.gh;

      xdg.data.files."gh/extensions/gh-stack".source = "${pkgs.gh-stack}/bin";

      xdg.config.files."gh/config.yml".generator = toYAML { };
      xdg.config.files."gh/config.yml".value = {
        version = 1;
      };

      xdg.config.files."git/config".generator = mkDefault toGitINI;
      xdg.config.files."git/config".value.credential."https://github.com".helper =
        "!${getExe pkgs.gh} auth git-credential";
    };

  flake.homeModules.git =
    { lib, pkgs, ... }:
    let
      inherit (lib.generators) toGitINI;
      inherit (lib.lists) singleton;
    in
    {
      packages = singleton pkgs.gitMinimal;

      xdg.config.files."git/config".generator = toGitINI;
      xdg.config.files."git/config".value = {
        user = {
          inherit (self.people.self) name email;
        };

        fetch.fsckObjects = true;
        receive.fsckObjects = true;
        transfer.fsckobjects = true;
      };
    };

  commonModules.version-control = config.commonModules.radicle;
  commonModules.radicle =
    { config, lib, ... }:
    let
      inherit (lib.attrsets) optionalAttrs;
    in
    {
      secrets.radicle = {
        file = ./radicle.age;
      }
      // optionalAttrs config.nixpkgs.hostPlatform.isDarwin {
        owner = config.system.primaryUser;
      };
    };

  flake.homeModules.radicle =
    {
      config,
      osConfig,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib.generators) toJSON;
      inherit (lib.lists) singleton;
    in
    {
      packages = singleton pkgs.radicle-node;

      xdg.data.files."radicle/config.json".generator = toJSON { };
      xdg.data.files."radicle/config.json".value = {
        publicExplorer = "https://radicle.network/nodes/$host/$rid$path";
        preferredSeeds = [
          "z6MkrLMMsiPWUcNPHcRajuMi9mDfYckSoJyPwwnknocNYPm7@iris.radicle.network:8776"
          "z6Mkmqogy2qEM2ummccUthFEaaHvyYmYBYh3dbe9W4ebScxo@rosa.radicle.network:8776"
        ];

        node.alias = self.people.self.name;
      };

      xdg.data.files."radicle/keys/radicle".source = osConfig.secrets.radicle.path;
      xdg.data.files."radicle/keys/radicle.pub".text = ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKl2Gn9hN40fRdk/l8rtPehYV5WfKjp1YaEUAzoWH9Wx radicle
      '';
    };

  flake.homeModules.jujutsu =
    {
      osConfig,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe;
      inherit (lib.strings) toLower;
    in
    {
      packages = singleton pkgs.jujutsu;

      xdg.config.files."jj/config.toml".generator = pkgs.writers.writeTOML "jj-config.toml";
      xdg.config.files."jj/config.toml".value = {
        user = {
          inherit (self.people.self) name email;
        };

        aliases.".." = [
          "edit"
          "@-"
        ];
        aliases.",," = [
          "edit"
          "@+"
        ];

        aliases.f = [
          "git"
          "fetch"
        ];

        aliases.p = [
          "git"
          "push"
        ];

        aliases.a = [ "abandon" ];

        aliases.c = [ "commit" ];
        aliases.ci = [
          "commit"
          "--interactive"
        ];

        aliases.d = [ "diff" ];

        aliases.e = [ "edit" ];

        aliases.l = [ "log" ];
        aliases.la = [
          "log"
          "--revisions"
          "::"
        ];

        aliases.s = [ "squash" ];
        aliases.si = [
          "squash"
          "--interactive"
        ];

        aliases.u = [ "undo" ];

        aliases.open = [
          "util"
          "exec"
          "--"
          (
            getExe
            <| pkgs.writers.writeNuBin "jj-open" /* nu */ ''
              def resolve-revision [revision: string] {
                do { jj --ignore-working-copy log --no-graph --template commit_id --revisions $revision }
                | complete
                | if $in.exit_code == 0 { $in.stdout }
              }

              def resolve-revision-in [--remote: any, symbol: string] {
                [(if $remote != null { $"($symbol)@($remote)" }) $symbol]
                | compact
                | where {|candidate| resolve-revision $candidate | is-not-empty }
                | get --optional 0
              }

              # Open a GitHub/Forgejo/etc URL locally, cloning the project to ~/Projects (by default) if it doesn't exist.
              def main [
                --at: path = ~/Projects # Directory the repository will be cloned into.
                url: string # URL to the file to open.
              ] {
                let span = (metadata $url).span
                let url = $url | url parse

                # PARSE
                let target = match ($url.path | split row "/" | where { is-not-empty }) {
                  [$owner, $repository] => {
                    owner: $owner,
                    repository: $repository,
                    revision: "@",
                    file: "."
                  }

                  # <owner>/<repository>/{blob,tree}/<revision>/<file>
                  [$owner, $repository, _, $revision, ..$file] => {
                    owner: $owner
                    repository: $repository
                    revision: $'"($revision)"'
                    file: ($file | path join | default "." --empty)
                  }

                  _ => {
                    error make {
                      msg: "not a repository url"
                      label: {
                        text: "expected <owner>/<repository>"
                        span: $span
                      }
                    }
                  }
                }
                | insert line ($url.fragment | parse --regex 'L(?<line>\d+)' | get --optional line.0)

                let repository_url = {
                  scheme: $url.scheme
                  host: $url.host
                  path: $"/($target.owner)/($target.repository)"
                }
                | url join

                # CLONE
                do --env {
                  let destination = $at | path join $target.repository

                  if not ($destination | path exists) {
                    jj git clone $repository_url $destination
                  }

                  cd $destination
                }

                # RESOLVE REMOTE
                let remote = do {
                  let existing = jj git remote list
                  | lines
                  | parse "{name} {url}"
                  | where {|remote| $remote.url | str replace --regex '\.git$' "" | str ends-with $"($target.owner)/($target.repository)" }
                  | get --optional name.0

                  if $existing != null {
                    return $existing
                  }

                  # Repository is a fork/upstream of the one on disk,
                  # so add it as a remote named after its owner.
                  jj git remote add $target.owner $repository_url
                  $target.owner
                }

                # RESOLVE SYMBOL
                let symbol = do {
                  let symbol = resolve-revision-in --remote $remote $target.revision

                  if $symbol != null {
                    return $symbol
                  }

                  jj git fetch --remote $remote
                  let symbol = resolve-revision-in --remote $remote $target.revision

                  if $symbol == null {
                    error make {
                      msg: $"unknown revision: ($target.revision)"
                      label: {
                        text: "from here"
                        span: $span
                      }
                    }
                  }

                  $symbol
                }

                # CHECKOUT
                if (resolve-revision $"($symbol) & @ | ($symbol) & @-" | is-empty) {
                  # Create a fresh revision and make it the workspace
                  # if the revision to open is not current or the parent.
                  jj new $symbol
                }

                # EDIT
                exec $env.EDITOR (match $target.line {
                  null => $target.file
                  $line => $"($target.file):($line)"
                })
              }
            ''
          )
        ];

        aliases.fork = [
          "util"
          "exec"
          "--"
          (
            getExe
            <| pkgs.writers.writeNuBin "jj-fork" /* nu */ ''
              def remote-names [] {
                jj git remote list | lines | parse "{name} {url}" | get name
              }

              if "upstream" not-in (remote-names) {
                jj git remote rename origin upstream
              }

              if "origin" not-in (remote-names) {
                gh repo fork --remote --remote-name origin
              }

              jj git fetch

              jj bookmark track (jj config get 'revset-aliases."trunk()"' | split row "@" | first)
            ''
          )
        ];

        revsets.bookmark-advance-from = # python
          ''
            coalesce(
              heads(::to & bookmarks() & ~immutable()),
              heads(::to & bookmarks()),
            )
          '';

        revsets.bookmark-advance-to = # python
          ''
            heads(::@ & mutable() & ~description(exact:"") & (~empty() | merges()))
          '';

        revsets.log = # python
          ''
            present(@) | present(trunk()) | ancestors(remote_bookmarks().. | @.., 8)
          '';

        ui.default-command = "log";

        ui.diff-editor = ":builtin";

        ui.conflict-marker-style = "snapshot";
        ui.graph.style = if osConfig.theme.cornerRadius > 0 then "curved" else "square";

        templates.draft_commit_description = # python
          ''
            concat(
              coalesce(description, "\n"),
              surround(
                "\nJJ: This commit contains the following changes:\n", "",
                indent("JJ:     ", diff.stat(72)),
              ),
              "\nJJ: ignore-rest\n",
              diff.git(),
            )
          '';

        templates.git_push_bookmark = # python
          ''
            "${toLower self.people.self.name}/change-" ++ change_id.short()
          '';

        remotes."*" = {
          auto-track-bookmarks = "${toLower self.people.self.name}/*";
          push-new-bookmarks = true;
        };

        git.fetch = [
          "origin"
          "upstream"
          "rad"
        ];
        git.push = "origin";

        # Drop signatures while editing, and sign on push.
        # This is nicer as I don't have to connect a hardware key to author a commit.
        signing.behavior = "drop";
        git.sign-on-push = true;

        signing.backend = "ssh";
        signing.key = self.people.self.ssh-key;
      };
    };

  flake.homeModules.difftastic =
    {
      osConfig,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.meta) getExe;
      inherit (lib.generators) toTOML;
      inherit (lib.lists) singleton;
      inherit (lib.modules) mkDefault;

      difft = pkgs.writeShellScriptBin "difft" /* bash */ ''
        exec ${getExe pkgs.difftastic} --background ${
          if osConfig.theme.isDark then "dark" else "light"
        } "$@"
      '';
    in
    {
      packages = singleton difft;

      xdg.config.files."jj/config.toml".generator = mkDefault toTOML;
      xdg.config.files."jj/config.toml".value.ui.diff-formatter = [
        (getExe difft)
        "--color"
        "always"
        "$left"
        "$right"
      ];
    };

  flake.homeModules.mergiraf =
    { lib, pkgs, ... }:
    let
      inherit (lib.generators) toTOML;
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkDefault;
    in
    {
      packages = singleton pkgs.mergiraf;

      xdg.config.files."jj/config.toml".generator = mkDefault toTOML;
      xdg.config.files."jj/config.toml".value = {
        aliases.resolve-ast = [
          "resolve"
          "--tool"
          "mergiraf"
        ];

        # Override the program with the absolute binary path.
        merge-tools.mergiraf.program = getExe pkgs.mergiraf;
      };
    };

  flake.homeModules.watchman =
    { lib, pkgs, ... }:
    let
      inherit (lib.generators) toJSON toTOML;
      inherit (lib.lists) singleton;
      inherit (lib.modules) mkDefault;
    in
    {
      packages = singleton pkgs.watchman;

      xdg.config.files."watchman/watchman.json".generator = toJSON { };
      xdg.config.files."watchman/watchman.json".value = {
        ignore_dirs = [
          ".direnv"
          "node_modules"
          "target"
        ];
      };

      xdg.config.files."jj/config.toml".generator = mkDefault toTOML;
      xdg.config.files."jj/config.toml".value = {
        fsmonitor.backend = "watchman";
        fsmonitor.watchman.register-snapshot-trigger = true;
      };
    };
}
