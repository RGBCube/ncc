{ config, lib, pkgs, ... }: let
  inherit (lib) attrValues const enabled getExe mapAttrs mkIf optionalAttrs readFile removeAttrs replaceString;
in {
  environment = optionalAttrs config.isLinux {
    sessionVariables.SHELLS = getExe pkgs.nushell;
  } // {
    shells = mkIf config.isDarwin [ pkgs.nushell ];

    shellAliases = {
      la  = "ls --all";
      lla = "ls --long --all";
      sl  = "ls";

      cp = "cp --recursive --verbose --progress";
      mk = "mkdir";
      mv = "mv --verbose";
      rm = "rm --recursive --verbose";

      pstree = "pstree -g 3";
      tree   = "eza --tree --git-ignore --group-directories-first";
    };

    systemPackages = attrValues {
      inherit (pkgs)
        fish   # For completions.
        zoxide # For completions and better cd.
      ;
    };

    variables.STARSHIP_LOG = "error";
  };

  nixpkgs.overlays = [(self: super: {
    starship = super.starship.overrideAttrs (old: {
      src = self.fetchFromGitHub {
        owner  = "poliorcetics";
        repo   = "starship";
        rev    = "92aba18381994599850053ba667c25017566b8ee";
        hash   = "sha256-FKDvkDcxUPDLcjFQzvqsGXeJUm0Dq8TcA4edf5OkdWo=";
      };

      cargoDeps = self.rustPlatform.fetchCargoVendor {
        inherit (self.starship) src;
        hash = "sha256-nH1iYjKw/GbYKadoymH3onWBbMzuMUaRCSTNWVE+A9E=";
      };

      nativeBuildInputs = old.nativeBuildInputs ++ [
        pkgs.cmake
        pkgs.zlib-ng
      ];
    });
  })];

  home-manager.sharedModules = [(homeArgs: let
    homeConfig = homeArgs.config;
  in {
    xdg.configFile = {
      "nushell/zoxide.nu".source = pkgs.runCommand "zoxide.nu" {} ''
        ${getExe pkgs.zoxide} init nushell --cmd cd > $out
      '';

      "nushell/ls_colors.txt".source = pkgs.runCommand "ls_colors.txt" {} ''
        ${getExe pkgs.vivid} generate gruvbox-dark-hard > $out
      '';

      "nushell/starship.nu".source = pkgs.runCommand "starship.nu" {} ''
        ${getExe pkgs.starship} init nu > $out
      '';
    };

    programs.starship = enabled {
      # No because we are doing it at build time instead of the way
      # this retarded module does it. Why the hell do you generate
      # the config every time the shell is launched?
      enableNushellIntegration = false;

      settings = {
        vcs.disabled = false;

        command_timeout = 100;
        scan_timeout    = 20;

        cmd_duration.show_notifications = config.isDesktop;

        package.disabled = config.isServer;

        character.error_symbol   = "";
        character.success_symbol = "";
      };
    };

    programs.direnv = enabled {
      nix-direnv = enabled;

      enableNushellIntegration = true;
    };

    programs.nushell = enabled {
      configFile.text = readFile ./config.nu;
      envFile.text    = readFile ./environment.nu;

      environmentVariables = let
        environmentVariables = config.environment.variables;

        homeVariables      = homeConfig.home.sessionVariables;
        # homeVariablesExtra = pkgs.runCommand "home-variables-extra.env" {} ''
        #     alias export=echo
        #     # echo foo > $out
        #     # FIXME
        #     eval $(cat ${homeConfig.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh) > $out
        #   ''
        #     # |> (aaa: (_: break _) aaa)
        #     |> readFile
        #     |> splitString "\n"
        #     |> filter (s: s != "")
        #     |> map (match "([^=]+)=(.*)")
        #     |> map (keyAndValue: nameValuePair (first keyAndValue) (last keyAndValue))
        #     |> foldl' (x: y: x // y) {};
        homeVariablesExtra = {};
      in environmentVariables // homeVariables // homeVariablesExtra
        |> mapAttrs (const <| replaceString "$HOME" homeConfig.home.homeDirectory);

      shellAliases = removeAttrs config.environment.shellAliases [ "ls" "l" ] // {
        cdtmp = "cd (mktemp --directory)";
        ll    = "ls --long";
      };
    };
  })];
}
