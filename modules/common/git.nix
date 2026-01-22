{ config, lib, pkgs, ... }: let
  inherit (lib) enabled merge mkIf;
in {
  environment.systemPackages = [
    pkgs.git-absorb
  ];

  home-manager.sharedModules = [(homeArgs: let
    config' = homeArgs.config;
  in {
    programs.difftastic.git = enabled;

    programs.git = enabled {
      lfs = enabled;

      settings = merge {
        user.name  = config'.programs.jujutsu.settings.user.name;
        user.email = config'.programs.jujutsu.settings.user.email;

        init.defaultBranch = "master";

        commit.verbose = true;

        log.date  = "iso";
        column.ui = "auto";

        branch.sort = "-committerdate";
        tag.sort    = "version:refname";

        diff.algorithm  = "histogram";
        diff.colorMoved = "default";

        pull.rebase          = true;
        push.autoSetupRemote = true;

        merge.conflictStyle = "zdiff3";

        rebase.autoSquash = true;
        rebase.autoStash  = true;
        rebase.updateRefs = true;
        rerere.enabled    = true;

        fetch.fsckObjects    = true;
        receive.fsckObjects  = true;
        transfer.fsckobjects = true;

        # https://bernsteinbear.com/git
        alias.recent = "! git branch --sort=-committerdate --format=\"%(committerdate:relative)%09%(refname:short)\" | head -10";
      } <| mkIf config.isDesktop {
        core.sshCommand                                  = "ssh -i ~/.ssh/id";
        url."ssh://git@github.com/".insteadOf            = "https://github.com/";

        commit.gpgSign  = true;
        tag.gpgSign     = true;

        gpg.format      = "ssh";
        user.signingKey = "~/.ssh/id";
      };
    };
  })];
}
