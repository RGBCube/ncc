{
  homeModules.bat =
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
    in
    {
      environment.sessionVariables = {
        MANPAGER = "${package} --plain";
        PAGER = "${package} --plain";
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
        --pager="${getExe pkgs.less} --quit-if-one-screen --RAW-CONTROL-CHARS"
      '';

      xdg.config.file."bat/themes/${theme}.tmTheme".text = config.theme.tmTheme;
    };
}
