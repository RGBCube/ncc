{ inputs, ... }:
{
  flake.nixosModules.nushell =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      inherit (lib.meta) getExe;
      inherit (lib.trivial) const;
      inherit (lib.attrsets)
        genAttrs
        mapAttrs
        mapAttrsToList
        zipAttrsWith
        ;
      inherit (lib.lists)
        concatLists
        concatMap
        toList
        ;
      inherit (lib.strings)
        concatLines
        concatStringsSep
        replaceStrings
        ;
    in
    {
      users.defaultUserShell = inputs.crash.packages.${pkgs.stdenv.hostPlatform.system}.default;
      environment.sessionVariables.SHELLS =
        [
          pkgs.nushell
          pkgs.bash
        ]
        |> map getExe
        |> concatStringsSep ":";

      environment.shells = map getExe [
        pkgs.nushell
        pkgs.bash
      ];

      environment.shellAliases = genAttrs [ "ls" "ll" "l" ] (const null);

      system.build.setEnvironmentNu =
        let
          absoluteVariables = config.environment.variables |> mapAttrs (const toList);

          suffixedVariables =
            config.environment.profileRelativeEnvVars
            |> mapAttrs (
              const (
                suffixes:
                config.environment.profiles |> concatMap (profile: map (suffix: "${profile}${suffix}") suffixes)
              )
            );

          allVariables = zipAttrsWith (const concatLists) [
            absoluteVariables
            suffixedVariables
          ];

          assignments =
            allVariables
            |> mapAttrsToList (
              name: segments: /* nu */ ''
                $env.${name} = $"${
                  segments
                  |> concatStringsSep ":"
                  |>
                    replaceStrings
                      [
                        "\${XDG_STATE_HOME}"
                        "\$HOME"
                        "\${HOME}"
                        "\$USER"
                        "\${USER}"
                      ]
                      [
                        "($env.XDG_STATE_HOME? | default ($env.HOME + '/.local/state'))"
                        "($env.HOME)"
                        "($env.HOME)"
                        "($env.USER)"
                        "($env.USER)"
                      ]
                }"
              ''
            )
            |> concatLines;
        in
        pkgs.writeText "set-environment.nu" ''
          if ($env.__NIXOS_SET_ENVIRONMENT? | is-not-empty) { } else {
            $env.__NIXOS_SET_ENVIRONMENT = "1"
            ${assignments}
          }
        '';
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
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkIf mkAfter mkBefore;
      inherit (lib.strings) readFile;
    in
    {
      xdg.config.files."zsh/.zshrc" = mkIf osConfig.nixpkgs.hostPlatform.isDarwin {
        text =
          # zsh
          mkAfter ''
            SHELL=${getExe config.programs.nushell.package} exec ${getExe config.programs.nushell.package} --login --config '${config.environment.sessionVariables.XDG_CONFIG_HOME}/nushell/config.nu'
          '';
      };

      xdg.config.files."nushell/config.nu".text =
        mkIf osConfig.nixpkgs.hostPlatform.isLinux
        <| mkBefore /* nu */ ''
          source ${osConfig.system.build.setEnvironmentNu}
        '';

      programs.nushell = {
        enable = true;

        extraConfig = readFile ./nushell.config.nu;

        aliases = {
          e = "^$env.EDITOR";

          la = "ls --all";
          ll = "ls --long";
          lla = "ls --long --all";

          cp = "cp --recursive --verbose --progress";
          mv = "mv --verbose";
          rm = "rm --recursive --verbose";

          pstree = "${getExe pkgs.pstree} -g 3";
          tree = "${getExe pkgs.eza} --tree --git-ignore --group-directories-first";
        };
      };
    };
}
