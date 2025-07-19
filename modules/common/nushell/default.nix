{ config, lib, pkgs, ... }: let
  inherit (lib) attrNames attrValues concatStringsSep const enabled filter flatten foldl' head last listToAttrs mapAttrs mapAttrsToList match nameValuePair readFile removeAttrs replaceStrings splitString;

  package = pkgs.nushell;
in {
  shells."0" = package;

  home-manager.sharedModules = [(homeArgs: let
    config' = homeArgs.config;
  in {
    programs.nushell = enabled {
      inherit package;

      configFile.text = readFile ./config.nu;

      extraConfig = /* nu */ ''
        $env.LS_COLORS = open ${config.environment.ls-colors}
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

        homeVariablesExtra = pkgs.runCommand "home-variables-extra.env" {} ''
            bash -ic '
              ${variablesMap
              |> mapAttrsToList (name: value: "export ${name}='${value}'")
              |> concatStringsSep "\n"}

              alias export=echo
              source ${config'.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh
            ' > $out
          ''
          |> readFile
          |> splitString "\n"
          |> filter (s: s != "")
          |> map (match "([^=]+)=(.*)")
          |> map (keyAndValue: nameValuePair (head keyAndValue) (last keyAndValue))
          |> foldl' (x: y: x // y) {};
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
