{ config, lib, pkgs, ... }: let
  inherit (lib) attrsToList catAttrs concatStringsSep const filter flatten foldl' getAttr getExe head last mapAttrs mapAttrsToList match mkConst mkIf mkValue nameValuePair readFile sortOn splitString toInt unique;
in {
  environment.shells = config.home-manager.users
  |> mapAttrsToList (const <| getAttr "shellsByPriority")
  |> flatten
  |> unique;

  home-manager.sharedModules = [

  (homeArgs: let
    config' = homeArgs.config;
  in {
    options.shells = mkValue {};

    options.shellsByPriority = mkConst (config'.shells
      |> attrsToList
      |> sortOn ({ name, ... }: toInt name)
      |> catAttrs "value");

    options.variablesMap = mkConst {
      HOME = config'.home.homeDirectory;
      USER = config'.home.username;

      XDG_CACHE_HOME  = config'.xdg.cacheHome;
      XDG_CONFIG_HOME = config'.xdg.configHome;
      XDG_DATA_HOME   = config'.xdg.dataHome;
      XDG_STATE_HOME  = config'.xdg.stateHome;
    };
  })

  (mkIf config.isDarwin (homeArgs: let
    config' = homeArgs.config;

    homeSessionVariables = let
      homeSessionVariables = config'.home.sessionVariables;

      homeSessionVariablesExtra = pkgs.runCommand "home-variables-extra.env" {} ''
          bash -ic '
            ${config'.variablesMap
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

      homeSessionSearchVariables = config'.home.sessionSearchVariables
        |> mapAttrs (const <| concatStringsSep ":");
    in homeSessionVariables
    // homeSessionVariablesExtra
    // homeSessionSearchVariables;
  in {
    home.file.".zshrc".text = /* zsh */ ''
      ${homeSessionVariables
      |> mapAttrsToList (name: value: "export ${name}='${value}'")
      |> concatStringsSep "\n"}

      if [ -z "$INTELLIJ_ENVIRONMENT_READER" ]; then
        SHELL='${getExe <| head config'.shellsByPriority}' exec "$SHELL"
      fi
    '';
  }))

  ];

  # More at modules/linux/shell/default.nix.
  #
  # Can't put that here with an optionalAttributes
  # becuase of an infinite recursion error, and can't
  # do that with a mkIf because the nix-darwin module
  # system doesn't have those attributes.
}
