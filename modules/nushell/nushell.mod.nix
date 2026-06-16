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
      inherit (lib) hashString;
      inherit (lib.meta) getExe;
      inherit (lib.trivial) const;
      inherit (lib.modules) mkForce;
      inherit (lib.attrsets)
        genAttrs
        mapAttrs
        mapAttrsToList
        zipAttrsWith
        ;
      inherit (lib.lists)
        concatLists
        concatMap
        reverseList
        singleton
        toList
        ;
      inherit (lib.strings)
        concatLines
        concatStringsSep
        replaceStrings
        splitString
        ;
    in
    {
      assertions = singleton {
        assertion =
          hashString "sha256" config.environment.extraInit
          == "36e519c7ce90530ada79c273393c0990b6f26faa4d54376d6a8eb30c872855a1";
        message = ''
          nushell: environment.extraInit changed, update system.build.setEnvironmentNu's Nu translation.

          Unexpected body:
          ${config.environment.extraInit}
        '';
      };

      users.defaultUserShell = inputs.crash.packages.${pkgs.stdenv.hostPlatform.system}.default;
      environment.sessionVariables.SHELLS = config.environment.shells |> concatStringsSep ":";
      environment.shells =
        mkForce
        <| map getExe [
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

          nuString =
            value:
            /* nu */ ''$"${
              value
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
            }"'';

          assignments =
            allVariables
            |> mapAttrsToList (
              name: segments:
              if name == "PATH" then
                /* nu */ ''
                  $env.PATH = [
                  ${segments |> concatMap (splitString ":") |> map (segment: "  ${nuString segment}") |> concatLines}
                  ]
                ''
              else
                /* nu */ ''
                  $env.${name} = ${nuString <| concatStringsSep ":" segments}
                ''
            )
            |> concatLines;

          extraInitNu = /* nu */ ''
            # Equivalent to the current NixOS environment.extraInit.
            $env.PATH = $env.PATH | prepend ${nuString "${config.security.wrapperDir}"}

            $env.NIX_USER_PROFILE_DIR = $"/nix/var/nix/profiles/per-user/($env.USER)"
            $env.NIX_PROFILES = ${
              config.environment.profiles |> reverseList |> concatStringsSep " " |> nuString
            }
          '';
        in
        pkgs.writeText "set-environment.nu" ''
          if ($env.__NIXOS_SET_ENVIRONMENT_DONE? | is-not-empty) { } else {
          $env.__NIXOS_SET_ENVIRONMENT_DONE = "1"
          ${assignments}
          ${extraInitNu}
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
    in
    {
      xdg.config.files."zsh/.zshrc" = mkIf osConfig.nixpkgs.hostPlatform.isDarwin {
        text = mkAfter /* zsh */ ''
          # Nested exec for the true shell to see the variables.
          SHELL=${getExe config.programs.nushell.package} exec ${getExe config.programs.nushell.package} \
            --login \
            --config '${config.environment.sessionVariables.XDG_CONFIG_HOME}/nushell/config.nu' \
            --execute 'exec $env.SHELL'
        '';
      };

      xdg.config.files."nushell/config.nu".text =
        mkIf osConfig.nixpkgs.hostPlatform.isLinux
        <| mkBefore /* nu */ ''
          source ${osConfig.system.build.setEnvironmentNu}
        '';

      programs.nushell = {
        enable = true;

        settings = {
          history.file_format = "sqlite";
          history.max_size = 1 * 1000 * 1000;

          show_banner = false;

          edit_mode = "vi";

          cursor_shape.emacs = "line";
          cursor_shape.vi_insert = "line";
          cursor_shape.vi_normal = "block";

          completions.algorithm = "substring";

          use_kitty_protocol = true;
          shell_integration.osc9_9 = true;

          highlight_resolved_externals = true;

          table.mode = "single";
          table.header_on_separator = true;
          table.footer_inheritance = true;
        };

        extraConfig = mkAfter "source ${
          pkgs.writeText "nushell-extra.nu" /* nu */ ''
            ulimit --file-descriptor-count hard

            $env.config.table.missing_value_symbol = $"(ansi magenta_bold)nope(ansi reset)"

            $env.config.datetime_format.normal = $"(ansi blue_bold)%Y(ansi reset)(ansi yellow)-(ansi blue_bold)%m(ansi reset)(ansi yellow)-(ansi blue_bold)%d(ansi reset)(ansi black)T(ansi magenta_bold)%H(ansi reset)(ansi yellow):(ansi magenta_bold)%M(ansi reset)(ansi yellow):(ansi magenta_bold)%S(ansi reset)"

            # Create a directory and cd into it.
            def --env mc [path: path]: nothing -> nothing {
              mkdir $path
              cd $path
            }

            # Create a directory, cd into it and initialize version control.
            def --env mcg [path: path]: nothing -> nothing {
              mkdir $path
              cd $path
              jj git init
            }
          ''
        }\n";

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
