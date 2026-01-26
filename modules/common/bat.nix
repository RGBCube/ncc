{ config, lib, pkgs, ... }: let
  inherit (lib) enabled getExe;

  batPager = pkgs.writeScript "bat-pager.sh" /* bash */ ''
    #!${getExe pkgs.bash}
    bat --plain
  '';
in {
  environment.variables = {
    MANPAGER = "${batPager}";
    PAGER    = "${batPager}";
  };
  environment.shellAliases = {
    cat  = "bat";
    less = "bat --plain";
  };

  home-manager.sharedModules = [{
    programs.bat = enabled {
      config.theme      = "base16";
      themes.base16.src = pkgs.writeText "base16.tmTheme" config.theme.tmTheme;

      config.pager = "less --quit-if-one-screen --quit-on-intr --RAW-CONTROL-CHARS";
    };
  }];
}
