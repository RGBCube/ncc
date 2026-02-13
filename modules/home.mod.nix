{ self, inputs, ... }:
{
  flake.homeModules.home =
    {
      config,
      lib,
      ...
    }:
    let
      inherit (lib.modules) mkAliasOptionModule;
    in
    {
      imports = [
        (mkAliasOptionModule [ "programs" ] [ "rum" "programs" ])
      ];

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

  flake.nixosModules.home =
    { lib, ... }:
    let
      inherit (lib.modules) mkAliasOptionModule;
    in
    {
      imports = [
        inputs.hjem.nixosModules.hjem
        (mkAliasOptionModule [ "home" ] [ "hjem" ])
      ];

      home.extraModules = [
        self.homeModules.home
        inputs.hjem-rum.hjemModules.hjem-rum
      ];
    };

  flake.darwinModules.home =
    { lib, ... }:
    let
      inherit (lib.modules) mkAliasOptionModule;
    in
    {
      imports = [
        inputs.hjem.darwinModules.hjem
        (mkAliasOptionModule [ "home" ] [ "hjem" ])
      ];

      home.extraModules = [
        self.homeModules.home
        inputs.hjem-rum.hjemModules.hjem-rum
      ];
    };
}
