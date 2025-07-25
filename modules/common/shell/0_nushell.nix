{ config, lib, pkgs, ... }: let
  inherit (lib) attrNames attrValues const enabled filterAttrs mapAttrs readFile replaceStrings;

  package = pkgs.nushell;
in {
  home-manager.sharedModules = [(homeArgs: let
    config' = homeArgs.config;

    environmentVariables = config.environment.variables
    |> mapAttrs (const <| replaceStrings (attrNames config'.variablesMap) (attrValues config'.variablesMap))
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
