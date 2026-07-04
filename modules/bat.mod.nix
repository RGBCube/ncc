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
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe getExe';
    in
    {
      environment.sessionVariables = {
        MANROFFOPT = "-c"; # Prevent groff from emitting ANSI color, bat does the highlighting.
        MANPAGER =
          getExe
          <| pkgs.writeScriptBin "man-pager" /* sh */ ''
            #!${getExe pkgs.bash}

            ${getExe' pkgs.util-linux "col"} --no-backspaces --spaces \
              | ${getExe pkgs.bat} --language man --plain --color always --paging never \
              | "$PAGER"
          '';

        PAGER =
          getExe
          <| pkgs.writeScriptBin "pager" /* sh */ ''
            #!${getExe pkgs.bash}

            unset LESS # systemd likes to set LESS, which messes with our settings

            exec ${getExe pkgs.less} \
              --quit-if-one-screen --quit-on-intr \
              --ignore-case --incsearch --LONG-PROMPT \
              --chop-long-lines --HILITE-UNREAD --tilde \
              --RAW-CONTROL-CHARS "$@"
          '';

        # Before v247, systemctl would spawn $PAGER, which was usually `less`,
        # without setting `LESSSECURE` even if both were launched as root.
        #
        # All was fine until someone realized with a rule that removes the wheel
        # requirement for `sudo systemctl status <unit>`, anyone could run any
        # command as root.
        #
        # As a result, systemd created a "pager secure" mode, where:
        # - It trusts your pager and exec's it. (happens regardless of the value of SYSTEMD_PAGERSECURE)
        # - It sets LESSSECURE in the pager environment, iff the SYSTEM_PAGERSECURE env var value is "1".
        #
        # If the env var is unset, you're not in "pager secure" mode and $PAGER is not exec'd.
        # (and instead falls back to less on path, and sets LESSSECURE if running under sudo/etc)
        SYSTEMD_PAGERSECURE = "0";
      };

      programs.nushell.aliases = {
        less = "^$env.PAGER";

        cat = getExe pkgs.bat;
      };

      packages = singleton pkgs.bat;

      xdg.config.files."bat/config".generator = toCliFlagList;
      xdg.config.files."bat/config".value.theme = "base16";
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
        ^/usr/bin/sudo --set-home --user r###'${config.system.primaryUser}'### -- ${getExe pkgs.bat} cache --build
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

        let users = r###'${
          config.users.users
          |> filterAttrs (_: user: user.isNormalUser)
          |> mapAttrsToList (name: _: name)
          |> toJSON
        }'### | from json

        for user in $users {
          ^${pkgs.util-linux}/bin/runuser --user $user -- ${getExe pkgs.bat} cache --build
        }
      '';
    };
}
