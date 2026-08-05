{ inputs, self, ... }:
{
  flake.nixosModules.shell = self.nixosModules.nushell;
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
          == "a9821b1c10a863d80fb60b639194548fbcb46a1fa57726beb777cbfd0b79a32c";
        message = ''
          nushell: environment.extraInit changed, update system.build.setEnvironmentNu's Nu translation.

          Unexpected body:
          ${config.environment.extraInit}
        '';
      };

      users.defaultUserShell = inputs.crash.packages.${pkgs.stdenv.hostPlatform.system}.default;
      environment.sessionVariables.SHELLS =
        [
          pkgs.nushell
          pkgs.bash
        ]
        |> map getExe
        |> concatStringsSep ":";

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
                  ${
                    segments
                    |> concatMap (splitString ":")
                    |> map (segment: "  ${nuString segment}")
                    |> concatLines
                  }
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
            $env.PATH = $env.PATH | prepend ${nuString config.security.wrapperDir}

            $env.NIX_USER_PROFILE_DIR = $"/nix/var/nix/profiles/per-user/($env.USER)"
            $env.NIX_PROFILES = ${
              config.environment.profiles
              |> reverseList
              |> concatStringsSep " "
              |> nuString
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

  flake.homeModules.shell.imports = [
    self.homeModules.nushell
    self.homeModules.shell-utils
  ];

  flake.homeModules.shell-utils =
    {
      osConfig,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) optionals;
    in
    {
      packages = [
        pkgs.fd
        pkgs.hyperfine
        pkgs.openssl
        pkgs.p7zip
        pkgs.rclone
        pkgs.tokei
        pkgs.typos
      ]
      ++ optionals osConfig.nixpkgs.hostPlatform.isLinux [
        pkgs.strace
        pkgs.usbutils
      ];
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
      inherit (lib.modules)
        mkIf
        mkAfter
        mkMerge
        mkOrder
        ;
      inherit (lib.attrsets) mapAttrsToList;
      inherit (lib.strings) concatLines toJSON;

      package = pkgs.nushell;
    in
    {
      files.".hushlogin" = mkIf osConfig.nixpkgs.hostPlatform.isDarwin { text = ""; };

      packages = [
        package
        pkgs.uutils-coreutils-noprefix
      ];

      xdg.config.files."zsh/.zshrc" = mkIf osConfig.nixpkgs.hostPlatform.isDarwin {
        text = mkAfter /* zsh */ ''
          # Nested exec for the true shell to see the variables.
          SHELL=${getExe package} exec ${getExe package} \
            --login \
            --config ${config.xdg.config.files."nushell/config.nu".source} \
            --execute 'exec $env.SHELL'
        '';
      };

      xdg.config.files."nushell/settings.nu".generator = settings: /* nu */ ''
        $env.config = $env.config | merge deep (r###'${toJSON settings}'### | from json)
      '';
      xdg.config.files."nushell/settings.nu".value = {
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

      xdg.config.files."nushell/aliases.nu".generator =
        aliases: aliases |> mapAttrsToList (name: body: "alias ${name} = ${body}") |> concatLines;
      xdg.config.files."nushell/aliases.nu".value = {
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

      xdg.config.files."nushell/config.nu".text = mkMerge [
        (
          mkIf osConfig.nixpkgs.hostPlatform.isLinux
          <| mkOrder 100 /* nu */ ''
            source ${osConfig.system.build.setEnvironmentNu}
          ''
        )

        (mkOrder 200 /* nu */ ''
          load-env (r###'${toJSON config.environment.sessionVariables}'### | from json)
        '')

        (mkOrder 300 /* nu */ ''
          source ${config.xdg.config.files."nushell/settings.nu".source}
        '')
        (mkOrder 400 /* nu */ ''
          source ${config.xdg.config.files."nushell/aliases.nu".source}
        '')

        (mkAfter "source ${
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

            # `which`, but with the paths of externals canonicalized.
            def realwhich [
              ...applications: string
              --all (-a) # List all executables.
            ]: nothing -> table {
              which --all=$all ...$applications
              | update path {|row| match $row.type {
                  "external" => { $row.path | path expand }
                  _ => $row.path
                } }
            }
          ''
        }")
      ];
    };
}
