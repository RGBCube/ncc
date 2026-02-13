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

      batPager = pkgs.writeScript "bat-pager.sh" /* bash */ ''
        #!${getExe pkgs.bash}
        ${getExe pkgs.bat} --plain
      '';
    in
    {
      environment.sessionVariables = {
        MANPAGER = "${batPager}";
        PAGER = "${batPager}";
      };

      programs.nushell.aliases = {
        cat = getExe pkgs.bat;
        less = "${getExe pkgs.bat} --plain";
      };

      packages = [
        pkgs.bat
        pkgs.less
      ];

      xdg.config.files."bat/config".generator = self.lib.generators.toCliFlagList;
      xdg.config.files."bat/config".value = {
        theme = "base16";
        pager = "${getExe pkgs.less} --quit-if-one-screen --quit-on-intr --RAW-CONTROL-CHARS";
      };

      xdg.config.files."bat/themes/base16.tmTheme".text = config.theme.tmTheme;
    };

  flake.darwinModules.bat =
    { config, pkgs, lib, ... }:
    let
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkAfter;
    in
    {
      system.activationScripts.script.text = mkAfter ''
        ${config.system.activationScripts.bat.text}
      '';
      system.activationScripts.bat.text = /* bash */ ''
        echo "refreshing bat cache..."
        ${getExe pkgs.bat} cache --build
      '';
    };

  flake.nixosModules.bat =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) filterAttrs mapAttrsToList;
      inherit (lib.meta) getExe;
      inherit (lib.strings) concatLines escapeShellArg;
    in
    {
      system.activationScripts.bat.text =
        config.users.users
        |> filterAttrs (
          _:
          {
            isNormalUser ? false,
            ...
          }:
          isNormalUser
        )
        |> mapAttrsToList (
          name: _: /* bash */ ''
            echo "refreshing bat cache..."
            ${pkgs.util-linux}/bin/runuser --user ${escapeShellArg name} --command ${escapeShellArg "${getExe pkgs.bat} cache --build"}
          ''
        )
        |> concatLines;
    };

}
