let
  commonModule =
    { lib, pkgs, ... }:
    let
      inherit (lib.modules) mkAliasOptionModule;
    in
    {
      imports = [ (mkAliasOptionModule [ "home" ] [ "hjem" ]) ];

      home =
        { config, lib, ... }:
        {
          # Temporary hack to make sure hjem sees the defaults are
          # changed and thus sets the appropriate XDG variables.
          # Remove after hjem gets proper Darwin support.
          options =
            let
              inherit (lib.lists) range;
              inherit (lib.modules) mkForce;
              inherit (lib.strings) concatStrings;
              inherit (lib.trivial) const;

              hasToBeChanged = range 0 (4096 / 2)
              |> map (const "No")
              |> concatStrings;
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
    };
in
{
  nixosModules.home =
    { inputs, ... }:
    {
      imports = [
        inputs.home.nixosModules.hjem

        commonModule
      ];
    };

  darwinModules.home =
    { inputs, ... }:
    {
      imports = [
        inputs.home.darwinModules.hjem

        commonModule
      ];
    };
}
