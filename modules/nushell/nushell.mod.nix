{ inputs, ... }:
{
  flake.nixosModules.nushell =
    {
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.meta) getExe;
      inherit (lib.trivial) const;
      inherit (lib.attrsets) genAttrs;
    in
    {
      users.defaultUserShell = inputs.crash.packages.${pkgs.stdenv.hostPlatform.system}.default;
      environment.sessionVariables.SHELLS = "${getExe pkgs.nushell}:${getExe pkgs.bash}";

      environment.shells = map getExe [
        pkgs.nushell
        pkgs.bash
      ];

      environment.shellAliases = genAttrs [ "ls" "ll" "l" ] (const null);
    };

  flake.homeModules.nushell =
    {
      config,
      osConfig,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib.attrsets)
        attrNames
        attrValues
        concatMapAttrs
        filterAttrs
        mapAttrs
        mapAttrsToList
        ;
      inherit (lib.lists)
        filter
        last
        ;
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkIf mkAfter;
      inherit (lib.trivial) const flip;
      inherit (lib.strings)
        concatStrings
        readFile
        replaceStrings
        splitString
        ;
    in
    let
      variablesMap =
        {
          HOME = config.directory;
          USER = config.directory |> splitString "/" |> filter (s: s != "") |> last;

          XDG_CACHE_HOME = config.xdg.cache.directory;
          XDG_CONFIG_HOME = config.xdg.config.directory;
          XDG_DATA_HOME = config.xdg.data.directory;
          XDG_STATE_HOME = config.xdg.state.directory;
        }
        |> concatMapAttrs (name: value: {
          "\$${name}" = value;
          "\${${name}}" = value;
        });

      nuVariables =
        osConfig.environment.variables
        |> flip removeAttrs [
          "XDG_CONFIG_DIRS"
          "XDG_DATA_DIRS"
          "EDITOR"
          "PAGER"
        ]
        |> mapAttrs (const <| replaceStrings (attrNames variablesMap) (attrValues variablesMap))
        |> filterAttrs (name: const <| name != "TERM");

      nuVariables' =
        nuVariables
        |> mapAttrsToList (
          name: value:
          # nu
          ''
            $env.${name} = "${value}"
          ''
        )
        |> concatStrings;

      nuConfig = nuVariables' + readFile ./nushell.config.nu;
    in
    {
      xdg.config.files."zsh/.zshrc" = mkIf osConfig.nixpkgs.hostPlatform.isDarwin {
        text =
          # zsh
          mkAfter ''
            SHELL=${getExe config.programs.nushell.package} exec ${getExe config.programs.nushell.package} --config '${config.environment.sessionVariables.XDG_CONFIG_HOME}/nushell/config.nu'
          '';
      };

      programs.nushell = {
        enable = true;

        extraConfig = nuConfig;

        aliases = {
          e = "^$env.EDITOR";

          la = "ls --all";
          ll = "ls --long";
          lla = "ls --long --all";
          sl = "ls";

          cp = "cp --recursive --verbose --progress";
          mk = "mkdir";
          mv = "mv --verbose";
          rm = "rm --recursive --verbose";

          pstree = "${getExe pkgs.pstree} -g 3";
          tree = "${getExe pkgs.eza} --tree --git-ignore --group-directories-first";
        };
      };
    };
}
