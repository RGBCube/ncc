let
  commonModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets)
        attrNames
        attrValues
        filterAttrs
        mapAttrs
        mapAttrsToList
        ;
      inherit (lib.lists)
        filter
        flatten
        last
        listToAttrs
        singleton
        ;
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkIf;
      inherit (lib.trivial) const;
      inherit (lib.strings)
        concatStrings
        readFile
        replaceStrings
        splitString
        ;
    in
    {
      home.extraModules = singleton (
        homeArgs:
        let
          config' = homeArgs.config;

          variablesMap =
            {
              HOME = config'.home.directory;
              USER = config'.home.directory |> splitString "/" |> filter (s: s != "") |> last;

              XDG_CACHE_HOME = config'.xdg.cache.directory;
              XDG_CONFIG_HOME = config'.xdg.config.directory;
              XDG_DATA_HOME = config'.xdg.data.directory;
              XDG_STATE_HOME = config'.xdg.state.directory;
            }
            |> mapAttrsToList (
              name: value: [
                {
                  name = "\$${name}";
                  inherit value;
                }
                {
                  name = "\${${name}}";
                  inherit value;
                }
              ]
            )
            |> flatten
            |> listToAttrs;

          nuVariables =
            config.environment.variables
            |> mapAttrs (const <| replaceStrings (attrNames variablesMap) (attrValues variablesMap))
            |> filterAttrs (name: const <| name != "TERM");

          nuVariables' =
            nuVariables
            |> mapAttrsToList (
              name: value:
              # nu
              ''
                $env.${name} = "${value}"
              ''
            )
            |> concatStrings;

          nuConfig = nuVariables' + readFile ./nushell.config.nu;

        in
        {
          home.file.".zshrc".text =
            mkIf config.nixpkgs.system.hostPlatform.isDarwin # zsh
              ''
                SHELL=${getExe config'.programs.nushell.package} exec ${getExe config'.programs.nushell.package}
              '';

          programs.nushell = {
            enable = true;

            extraConfig = nuConfig;

            aliases = {
              la = "ls --all";
              ll = "ls --long";
              lla = "ls --long --all";
              sl = "ls";

              cp = "cp --recursive --verbose --progress";
              mk = "mkdir";
              mv = "mv --verbose";
              rm = "rm --recursive --verbose";

              pstree = "${getExe pkgs.pstree} -g 3";
              tree = "${getExe pkgs.eza} --tree --git-ignore --group-directories-first";
            };
          };
        }
      );
    };
in
{
  nixosModules.nushell =
    { lib, pkgs, ... }:
    let
      inherit (lib.modules) mkForce;
    in
    {
      imports = [ commonModule ];

      users.defaultUserShell = pkgs.nushell;

      environment.shellAliases = {
        ls = mkForce null;
        l = mkForce null;
      };
    };

  darwinModules.nushell = commonModule;
}
