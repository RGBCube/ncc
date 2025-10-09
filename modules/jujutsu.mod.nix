let
  commonModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe;
      inherit (lib.generators) toTOML;

    in
    {
      environment.systemPackages = [
        pkgs.difftastic
        pkgs.jujutsu
        pkgs.mergiraf
        pkgs.radicle-node
      ];

      home.extraModules = singleton {
        xdg.config.file."jj/config.toml".generator = toTOML;
        xdg.config.file."jj/config.toml".value = {
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

          aliases.f = [ "fetch" ];
          aliases.fetch = [
            "git"
            "fetch"
          ];

          aliases.p = [ "push" ];
          aliases.push = [
            "git"
            "push"
          ];

          aliases.cl = [ "clone" ];
          aliases.clone = [
            "git"
            "clone"
            "--colocate"
          ];

          aliases.i = [ "init" ];
          aliases.init = [
            "git"
            "init"
            "--colocate"
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
          aliases.ls = [
            "log"
            "--summary"
          ];
          aliases.lsa = [
            "log"
            "--summary"
            "--revisions"
            "::"
          ];
          aliases.lp = [
            "log"
            "--patch"
          ];
          aliases.lpa = [
            "log"
            "--patch"
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

          aliases.t = [ "tug" ];
          aliases.tug = [
            "bookmark"
            "move"
            "--from"
            "closest(@-)"
            "--to"
            "closest_pushable(@)"
          ];

          aliases.u = [ "undo" ];

          revset-aliases."closest(to)" = # python
            ''
              heads(::to & bookmarks())
            '';
          revset-aliases."closest_pushable(to)" = # python
            ''
              heads(::to & ~description(exact:"") & (~empty() | merges()))
            '';

          revsets.log = # python
            ''
              present(@) | present(trunk()) | ancestors(remote_bookmarks().. | @.., 8)
            '';

          ui.default-command = "ls";

          ui.diff-editor = ":builtin";
          ui.diff-formatter = [
            "${getExe pkgs.difftastic}"
            "--color"
            "always"
            "$left"
            "$right"
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

          git.auto-local-bookmark = true;

          git.fetch = [
            "origin"
            "upstream"
            "rad"
          ];
          git.push = "origin";

          signing.backend = "ssh";
          signing.behavior = "own";
          signing.key = "~/.ssh/id";
        };
      };
    };
in
{
  nixosModules.jujutsu = commonModule;
  darwinModules.jujutsu = commonModule;
}
