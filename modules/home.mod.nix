{ self, ... }:
{
  homeModules.home =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      inherit (lib.modules) mkAliasOptionModule;
    in
    {
      imports = [
        (mkAliasOptionModule [ "programs" ] [ "rum" "programs" ])
      ];

      # Temporary hack to make sure hjem sees the defaults are
      # changed and thus sets the appropriate XDG variables.
      # Remove after hjem gets proper Darwin support.
      options =
        let
          inherit (lib.lists) range;
          inherit (lib.modules) mkForce;
          inherit (lib.strings) concatStrings;
          inherit (lib.trivial) const;

          hasToBeChanged = range 0 (4096 / 2) |> map (const "No") |> concatStrings;
        in
        {
          xdg.cache.directory.default = mkForce hasToBeChanged;
          xdg.config.directory.default = mkForce hasToBeChanged;
          xdg.data.directory.default = mkForce hasToBeChanged;
          xdg.state.directory.default = mkForce hasToBeChanged;
        };

      config = {
        linker = pkgs.smfh;

        # These are already the default on Linux, but on Darwin they differ.
        xdg.cache.directory = "${config.directory}/.cache";
        xdg.config.directory = "${config.directory}/.config";
        xdg.data.directory = "${config.directory}/.local/share";
        xdg.state.directory = "${config.directory}/.local/state";
      };
    };

  nixosModules.home =
    { inputs, lib, ... }:
    let
      inherit (lib.modules) mkAliasOptionModule;
    in
    {
      imports = [
        inputs.home.nixosModules.hjem
        (mkAliasOptionModule [ "home" ] [ "hjem" ])

        { home.extraModules = [ self.homeModules.home ]; }
      ];
    };

  darwinModules.home =
    { inputs, lib, ... }:
    let
      inherit (lib.modules) mkAliasOptionModule;
    in
    {
      imports = [
        inputs.home.darwinModules.hjem
        (mkAliasOptionModule [ "home" ] [ "hjem" ])

        { home.extraModules = [ self.homeModules.home ]; }
      ];
    };
}
