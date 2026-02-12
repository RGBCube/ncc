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

      # Hack to make hjem think the XDG defaults changed, so it
      # actually sets the XDG env vars. Without this, Darwin programs
      # fall back to ~/Library/Application Support/ instead of ~/.config.
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
        # These are already the default on Linux, but on Darwin they differ.
        xdg.cache.directory = "${config.directory}/.cache";
        xdg.config.directory = "${config.directory}/.config";
        xdg.data.directory = "${config.directory}/.local/share";
        xdg.state.directory = "${config.directory}/.local/state";
      };
    };

  flake.nixosModules.home =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.modules) mkAliasOptionModule;
    in
    {
      imports = [
        inputs.home.nixosModules.hjem
        (mkAliasOptionModule [ "home" ] [ "hjem" ])

        { home.extraModules = singleton self.homeModules.home; }
      ];
    };

  flake.darwinModules.home =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.modules) mkAliasOptionModule;
    in
    {
      imports = [
        inputs.home.darwinModules.hjem
        (mkAliasOptionModule [ "home" ] [ "hjem" ])

        { home.extraModules = singleton self.homeModules.home; }
      ];
    };
}
