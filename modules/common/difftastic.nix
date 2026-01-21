{ lib, ... }: let
  inherit (lib) enabled;
in {
  home-manager.sharedModules = [{
    programs.difftastic = enabled {
      options.background = "dark";
    };
  }];
}
