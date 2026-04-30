{
  flake.nixosModules.persist =
    { lib, config, ... }:
    let
      inherit (lib.attrsets) listToAttrs;
      inherit (lib.lists) map;
      inherit (lib.modules) mkIf;
      inherit (lib.options) mkEnableOption mkOption;
      inherit (lib.strings) removePrefix replaceStrings;
      inherit (lib.types) listOf path;
    in
    {
      options.persist = {
        enable = mkEnableOption "bcachefs subvolume persistence";

        paths = mkOption {
          type = listOf path;
          default = [ ];
          description = "Paths to persist as bcachefs subvolumes under the root filesystem.";
        };
      };

      config = mkIf (config.persist.enable && config.persist.paths != [ ]) {
        disko.devices.bcachefs_filesystems."persist".subvolumes =
          config.persist.paths
          |> map (mountpoint: {
            name = mountpoint |> removePrefix "/" |> replaceStrings [ "/" ] [ "-" ];
            value.mountpoint = mountpoint;
          })
          |> listToAttrs;
      };
    };
}
