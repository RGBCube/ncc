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
        git_protocol = "ssh";
      };
    };

  flake.homeModules.git =
    { lib, pkgs, ... }:
    let
      inherit (lib.meta) getExe;
      inherit (lib.generators) toGitINI;
      inherit (lib.lists) singleton;

      package = getExe pkgs.git;
    in
    {
      packages = singleton pkgs.git-absorb;

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
          ''! ${package} branch --sort=-committerdate --format="%(committerdate:relative)%09%(refname:short)" | head -10'';
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
}
