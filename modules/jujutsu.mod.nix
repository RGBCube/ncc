{
  flake.homeModules.jujutsu =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.meta) getExe;
      inherit (lib.strings) readFile;

      toTOML = value: readFile <| pkgs.writers.writeTOML "workaround.toml" value;
    in
    {
      packages = [
        pkgs.jjui
        pkgs.jujutsu
        pkgs.mergiraf
      ];

      xdg.config.files."jj/config.toml".generator = toTOML;
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
