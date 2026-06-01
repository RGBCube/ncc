{
  flake.homeModules.bat =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.generators) toCliFlagList;
      inherit (lib.meta) getExe;

      batPager = pkgs.writeScriptBin "bat-pager" /* bash */ ''
        #!${getExe pkgs.bash}

        ${getExe pkgs.bat} --plain
      '';
    in
    {
      environment.sessionVariables = {
        MANPAGER = "${getExe batPager}";
        PAGER = "${getExe batPager}";
      };

      programs.nushell.aliases = {
        cat = getExe pkgs.bat;
        less = "${getExe pkgs.bat} --plain";
      };

      packages = [
        pkgs.bat
        pkgs.less
      ];

      xdg.config.files."bat/config".generator = toCliFlagList;
      xdg.config.files."bat/config".value = {
        theme = "base16";
        pager = "${getExe pkgs.less} --quit-if-one-screen --quit-on-intr --RAW-CONTROL-CHARS";
      };

      xdg.config.files."bat/themes/base16.tmTheme".text = config.theme.tmTheme;
    };

  flake.darwinModules.bat =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkAfter;
      inherit (lib.shell) asShell;
    in
    {
      system.activationScripts.script.text = mkAfter ''
        ${config.system.activationScripts.bat.text}
      '';
      system.activationScripts.bat.text = asShell pkgs.nushell "bat-cache.nu" /* nu */ ''
        print "refreshing bat cache..."
        ^/usr/bin/sudo --set-home --user r##'${config.system.primaryUser}'## -- ${getExe pkgs.bat} cache --build
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
      inherit (lib.shell) asShell;
      inherit (lib.strings) toJSON;
    in
    {
      system.activationScripts.bat.text = asShell pkgs.nushell "bat-cache.nu" /* nu */ ''
        print "refreshing bat cache..."

        let users = r##'${
          config.users.users
          |> filterAttrs (_: user: user.isNormalUser)
          |> mapAttrsToList (name: _: name)
          |> toJSON
        }'## | from json

        for user in $users {
          ^${pkgs.util-linux}/bin/runuser --user $user -- ${getExe pkgs.bat} cache --build
        }
      '';
    };

}
