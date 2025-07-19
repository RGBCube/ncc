{ config, lib, pkgs, ... }: let
  inherit (lib) enabled;
in {
  environment.variables = {
    MANPAGER = "bat --plain";
    PAGER    = "bat --plain";
  };
  environment.shellAliases = {
    cat  = "bat";
    less = "bat --plain";
  };

  home-manager.sharedModules = [{
    programs.bat = enabled {
      config.theme      = "base16";
      themes.base16.src = pkgs.writeText "base16.tmTheme" config.theme.tmTheme;

      config.pager = "less --quit-if-one-screen --RAW-CONTROL-CHARS";
    };
  }];
}
