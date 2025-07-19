{ config, lib, pkgs, ... }: let
  inherit (lib) attrNames attrValues concatStringsSep const enabled flatten getExe listToAttrs mapAttrs mapAttrsToList mkIf optionalAttrs readFile removeAttrs replaceStrings;
in {
  environment = optionalAttrs config.isLinux {
    sessionVariables.SHELLS = getExe pkgs.nushell;
  } // {
    shells = mkIf config.isDarwin [ pkgs.nushell ];

    shellAliases = {
      la  = "ls --all";
      ll  = "ls --long";
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
        carapace      # For completions.
        fish          # For completions.
        zsh           # For completions.
        inshellisense # For completions.
      ;
    };
  };

  home-manager.sharedModules = [(homeArgs: let
    config' = homeArgs.config;
  in {
    programs.carapace = enabled {
      enableNushellIntegration = true;
    };

    programs.direnv = enabled {
      enableNushellIntegration = true;

      nix-direnv = enabled;
    };

    programs.zoxide = enabled {
      enableNushellIntegration = true;

      options = [ "--cmd cd" ];
    };

    programs.nushell = enabled {
      configFile.text = readFile ./config.nu;

      extraConfig = ''
        $env.LS_COLORS = open ${pkgs.runCommand "ls_colors.txt" {} ''
          ${getExe pkgs.vivid} generate gruvbox-dark-hard > $out
        ''}
      '';

      environmentVariables = let
        variablesMap = {
          HOME = config'.home.homeDirectory;
          USER = config'.home.username;

          XDG_CACHE_HOME  = config'.xdg.cacheHome;
          XDG_CONFIG_HOME = config'.xdg.configHome;
          XDG_DATA_HOME   = config'.xdg.dataHome;
          XDG_STATE_HOME  = config'.xdg.stateHome;
        }
        |> mapAttrsToList (name: value: [
          { name = "\$${name}"; inherit value; }
          { name = "\${${name}}"; inherit value; }
        ])
        |> flatten
        |> listToAttrs;

        environmentVariables = config.environment.variables;

        homeVariables = config'.home.sessionVariables;

        homeSearchVariables = config'.home.sessionSearchVariables
          |> mapAttrs (const <| concatStringsSep ":");

        # homeVariablesExtra = pkgs.runCommand "home-variables-extra.env" {} ''
        #     alias export=echo
        #     # echo foo > $out
        #     # FIXME
        #     eval $(cat ${config'.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh) > $out
        #   ''
        #     # |> (aaa: (_: break _) aaa)
        #     |> readFile
        #     |> splitString "\n"
        #     |> filter (s: s != "")
        #     |> map (match "([^=]+)=(.*)")
        #     |> map (keyAndValue: nameValuePair (first keyAndValue) (last keyAndValue))
        #     |> foldl' (x: y: x // y) {};
        homeVariablesExtra = {};
      in environmentVariables
      // homeVariables
      // homeSearchVariables
      // homeVariablesExtra
      |> mapAttrs (const <| replaceStrings (attrNames variablesMap) (attrValues variablesMap));

      shellAliases = removeAttrs config.environment.shellAliases [ "ls" "l" ] // {
        cdtmp = "cd (mktemp --directory)";
      };
    };
  })];
}
