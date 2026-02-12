{ self, ... }:
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

      xdg.config.files."bat/config".generator = self.lib.generators.toCliFlagList;
      xdg.config.files."bat/config".value = {
        theme = "base16";
        pager = "${getExe pkgs.less} --quit-if-one-screen --quit-on-intr --RAW-CONTROL-CHARS";
      };

      xdg.config.files."bat/themes/${config.xdg.config.files."bat/config".value.theme}.tmTheme".text = config.theme.tmTheme;
    };
}
