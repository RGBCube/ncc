{ self, ... }:
{
  flake.homeModules.gh =
    { lib, pkgs, ... }:
    let
      inherit (lib.generators) toYAML;
    in
    {
      packages = [
        pkgs.gh
      ];

      xdg.config.files."gh/config.yml".generator = toYAML { };
      xdg.config.files."gh/config.yml".value = {
        version = 1;
      };
    };

  flake.homeModules.git =
    { lib, pkgs, ... }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.generators) toGitINI;
    in
    {
      packages = singleton pkgs.gitMinimal;

      xdg.config.files."git/config".generator = toGitINI;
      xdg.config.files."git/config".value = {
        user.name = "RGBCube";
        user.email = "git@rgbcu.be";

        fetch.fsckObjects = true;
        receive.fsckObjects = true;
        transfer.fsckobjects = true;

        url."ssh://git@github.com/".insteadOf = "https://github.com/";
      };
    };

  flake.homeModules.jujutsu =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.meta) getExe;
    in
    {
      packages = [
        pkgs.jjui
        pkgs.jujutsu
        pkgs.mergiraf
      ];

      xdg.config.files."jj/config.toml".generator = pkgs.writers.writeTOML "jj-config.toml";
      xdg.config.files."jj/config.toml".value = {
        user.name = "RGBCube";
        user.email = "git@rgbcu.be";

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

        aliases.cl = [
          "git"
          "clone"
        ];

        aliases.i = [
          "git"
          "init"
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

        aliases.r = [ "rebase" ];

        aliases.res = [ "resolve" ];

        aliases.resa = [ "resolve-ast" ];
        aliases.resolve-ast = [
          "resolve"
          "--tool"
          "${getExe pkgs.mergiraf}"
        ];

        aliases.s = [ "squash" ];
        aliases.si = [
          "squash"
          "--interactive"
        ];

        aliases.sh = [ "show" ];

        aliases.u = [ "undo" ];

        aliases.fork = [
          "util"
          "exec"
          "--"
          (pkgs.writeScript "jj-fork" /* nu */ ''
            #!${getExe pkgs.nushell}
            #

            gh repo fork --remote
            gh repo set-default upstream

            jj git fetch

            let trunk = jj config get 'revset-aliases."trunk()"'

            jj bookmark track ($trunk | split row "@" | first) --remote upstream
            jj bookmark track ($trunk | split row "@" | first) --remote origin
            jj config set --repo 'revset-aliases."trunk()"' ($trunk | str replace "origin" "upstream")
          '')
        ];

        revsets.bookmark-advance-to = # python
          ''
            heads(::@ & ~description(exact:"") & (~empty() | merges()))
          '';

        revsets.log = # python
          ''
            present(@) | present(trunk()) | ancestors(remote_bookmarks().. | @.., 8)
          '';

        ui.default-command = "log";

        ui.diff-editor = ":builtin";
        ui.pager = [
          (getExe pkgs.bash)
          "-c"
          "exec \${PAGER:-less}"
        ];

        ui.conflict-marker-style = "snapshot";
        ui.graph.style = if config.theme.cornerRadius > 0 then "curved" else "square";

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
            "rgbcube/change-" ++ change_id.short()
          '';

        remotes."*" = {
          auto-track-bookmarks = "rgbcube/*";
          push-new-bookmarks = true;
        };

        git.fetch = [
          "origin"
          "upstream"
          "rad"
        ];
        git.push = "origin";
        git.sign-on-push = true;

        signing.backend = "ssh";
        signing.behavior = "drop"; # To not error on leftover signatures from the past.
        signing.key = self.keys.rgbcube;
      };
    };
}
