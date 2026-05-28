{ inputs, ... }:
{
  flake.homeModules.home =
    {
      config,
      lib,
      ...
    }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.modules) mkAliasOptionModule;
    in
    {
      imports = singleton <| mkAliasOptionModule [ "programs" ] [ "rum" "programs" ];

      # FORCE XDG ENV VARS
      # hjem only exports XDG_*_HOME when config value != option default.
      # The defaults do not match platform realities and setting the Linux
      # defaults here causes env vars to not be set. Setting them directly
      # bypasses hjem's conditional logic.
      environment.sessionVariables = {
        XDG_CACHE_HOME = "${config.directory}/.cache";
        XDG_CONFIG_HOME = "${config.directory}/.config";
        XDG_DATA_HOME = "${config.directory}/.local/share";
        XDG_STATE_HOME = "${config.directory}/.local/state";
      };
    };

  flake.commonModules.home =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.modules) mkAliasOptionModule;
    in
    {
      imports = singleton <| mkAliasOptionModule [ "home" ] [ "hjem" ];

      home.specialArgs = { inherit lib; };

      home.extraModules = singleton inputs.hjem-rum.hjemModules.hjem-rum;

      home.clobberByDefault = true;
    };

  flake.nixosModules.home =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      imports = singleton inputs.hjem.nixosModules.hjem;

      home.users.root = { };
    };

  flake.darwinModules.home = inputs.hjem.darwinModules.hjem;
}
