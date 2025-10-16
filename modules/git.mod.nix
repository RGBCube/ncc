{ self, ... }:
{
  homeModules.gh =
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

      xdg.config.file."gh/config.yml".generator = toYAML { };
      xdg.config.file."gh/config.yml".value = {
        git_protocol = "ssh";
      };
    };

  homeModules.git =
    { lib, pkgs, ... }:
    let
      inherit (lib.meta) getExe;
      inherit (lib.generators) toINI;

      package = getExe pkgs.git;
    in
    {
      programs.nushell.aliases = {
        g = package;

        ga = "${package} add";
        gaa = "${package} add ./";

        gab = "${package} absorb";
        gabr = "${package} absorb --and-rebase";

        gb = "${package} branch";
        gbv = "${package} branch --verbose";

        gc = "${package} commit";
        gca = "${package} commit --amend --no-edit";
        gcm = "${package} commit --message";
        gcam = "${package} commit --amend --message";

        gcl = "${package} clone";

        gd = "${package} diff";
        gds = "${package} diff --staged";

        gp = "${package} push";
        gpf = "${package} push --force-with-lease";

        gl = "${package} log";
        glo = "${package} log --oneline --graph";
        glp = "${package} log --patch --ext-diff";

        gpl = "${package} pull";
        gplr = "${package} pull --rebase";
        gplff = "${package} pull --ff-only";

        gr = "${package} recent";

        grb = "${package} rebase";
        grba = "${package} rebase --abort";
        grbc = "${package} rebase --continue";
        grbi = "${package} rebase --interactive";
        grbm = "${package} rebase master";

        grl = "${package} reflog";

        grm = "${package} remote";
        grma = "${package} remote add";
        grmv = "${package} remote --verbose";
        grmsu = "${package} remote set-url";

        grs = "${package} reset";
        grsh = "${package} reset --hard";

        gs = "${package} stash";
        gsp = "${package} stash pop";

        gsw = "${package} switch";
        gswm = "${package} switch master";

        gsh = "${package} show --ext-diff";

        gst = "${package} status";
      };

      packages = [
        package
        pkgs.difftastic
      ];

      xdg.config.file."git/config".generator = toINI { };
      xdg.config.file."git/config".value = {
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

        diff.external = getExe pkgs.difftastic;
        diff.tool = "difftastic";
        difftool.difftastic.cmd = # sh
          ''${getExe pkgs.difftastic} "$LOCAL" "$REMOTE"'';

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

  homeModules.git-sign =
    { config, lib, ... }:
    let
      inherit (lib.generators) toINI;
    in
    {
      imports = [ self.homeModules.git ];

      xdg.config.file."git/config".generator = toINI { };
      xdg.config.file."git/config".value = {
        core.sshCommand = "ssh -i ${config.directory}/.ssh/id";

        url."ssh://git@github.com/".insteadOf = "https://github.com/";

        commit.gpgSign = true;
        tag.gpgSign = true;

        gpg.format = "ssh";
        user.signingKey = "~/.ssh/id";
      };
    };
}
