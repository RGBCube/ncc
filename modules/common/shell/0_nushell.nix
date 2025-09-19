{ config, lib, pkgs, ... }: let
  inherit (lib) attrNames attrValues const enabled filterAttrs flatten listToAttrs mapAttrs mapAttrsToList readFile replaceStrings;

  package = pkgs.nushell;
in {
  home-manager.sharedModules = [(homeArgs: let
    config' = homeArgs.config;

    environmentVariables = let
      variablesMap = config'.variablesMap
        |> mapAttrsToList (name: value: [
          { name = "\$${name}"; inherit value; }
          { name = "\${${name}}"; inherit value; }
        ])
        |> flatten
        |> listToAttrs;
    in config.environment.variables
    |> mapAttrs (const <| replaceStrings (attrNames variablesMap) (attrValues variablesMap))
    |> filterAttrs (name: const <| name != "TERM");
  in {
    shells."0" = package;

    programs.nushell = enabled {
      inherit package;

      inherit environmentVariables;

      shellAliases = config.environment.shellAliases
        |> filterAttrs (_: value: value != null);

      configFile.text = readFile ./0_nushell.nu;
    };
  })];
}
