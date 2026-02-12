{
  flake.homeModules.bat =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.meta) getExe;

      package = getExe pkgs.bat;
      theme = "base16";

      batPager = pkgs.writeScript "bat-pager.sh" /* bash */ ''
        #!${getExe pkgs.bash}
        bat --plain
      '';
    in
    {
      environment.sessionVariables = {
        MANPAGER = "${batPager}";
        PAGER = "${batPager}";
      };

      programs.nushell.aliases = {
        cat = package;
        less = "${package} --plain";
      };

      packages = [
        pkgs.bat
      ];

      xdg.config.file."bat/config".text = ''
        --theme=${theme}
        --pager="${getExe pkgs.less} --quit-if-one-screen --quit-on-intr --RAW-CONTROL-CHARS"
      '';

      xdg.config.file."bat/themes/${theme}.tmTheme".text = config.theme.tmTheme;
    };
}
