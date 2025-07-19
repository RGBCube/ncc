{ config, lib, pkgs, ... }: let
  inherit (lib) attrNames attrValues concatStringsSep const enabled filter filterAttrs flatten foldl' head last listToAttrs mapAttrs mapAttrsToList match nameValuePair readFile replaceStrings splitString;

  package = pkgs.nushell;
in {
  shells."0" = package;

  home-manager.sharedModules = [(homeArgs: let
    config' = homeArgs.config;

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

      homeSearchVariables = config'.home.sessionSearchVariables
        |> mapAttrs (const <| concatStringsSep ":");
    in environmentVariables
    // homeVariables
    // homeVariablesExtra
    // homeSearchVariables
    |> mapAttrs (const <| replaceStrings (attrNames variablesMap) (attrValues variablesMap))
    |> filterAttrs (name: const <| name != "TERM");
  in {
    programs.nushell = enabled {
      inherit package;

      inherit (config.environment) shellAliases;
      inherit environmentVariables;

      configFile.text = readFile ./0_nushell.nu;
    };
  })];
}
