{ self, ... }:
{
  flake.homeModules.gh =
    { lib, pkgs, ... }:
    let
      inherit (lib.generators) toYAML;
      inherit (lib.meta) getExe;

      package = getExe pkgs.gh;
    in
    {
      programs.nushell.aliases = {
        "??" = "${package} copilot suggest --target shell --";
        "gh?" = "${package} copilot suggest --target gh --";
        "git?" = "${package} copilot suggest --target git --";
      };

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

        init.defaultBranch = "master";

        commit.verbose = true;

        log.date = "iso";
        column.ui = "auto";

        branch.sort = "-committerdate";
        tag.sort = "version:refname";

        diff.algorithm = "histogram";
        diff.colorMoved = "default";

        pull.rebase = true;
        push.autoSetupRemote = true;

        merge.conflictStyle = "zdiff3";

        rebase.autoSquash = true;
        rebase.autoStash = true;
        rebase.updateRefs = true;

        rerere.enabled = true;

        fetch.fsckObjects = true;
        receive.fsckObjects = true;
        transfer.fsckobjects = true;

        alias.recent = # sh
          ''! git branch --sort=-committerdate --format="%(committerdate:relative)%09%(refname:short)" | head -10'';
      };
    };

  flake.homeModules.git-sign =
    { config, lib, ... }:
    let
      inherit (lib.generators) toGitINI;
    in
    {
      # xdg.config.files."git/config".generator = toGitINI; # FIXME
      xdg.config.files."git/config".value = {
        url."ssh://git@github.com/".insteadOf = "https://github.com/";

        commit.gpgSign = true;
        tag.gpgSign = true;

        gpg.format = "ssh";
        user.signingKey = "${config.xdg.config.directory}/ssh/key.pub";
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

        revsets.bookmark-advance-to = # python
          ''
            heads(::@ & ~description(exact:"") & (~empty() | merges()))
          '';

        revsets.log = # python
          ''
            present(@) | present(trunk()) | ancestors(remote_bookmarks().. | @.., 8)
          '';

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
            "change-rgbcube-" ++ change_id.short()
          '';

        remotes."*" = {
          auto-track-bookmarks = "glob:*";
          push-new-bookmarks = true;
        };

        git.fetch = [
          "origin"
          "upstream"
          "rad"
        ];
        git.push = "origin";

        signing.backend = "ssh";
        signing.behavior = "own";
        signing.key = "${config.xdg.config.directory}/ssh/key.pub";
      };
    };
}
