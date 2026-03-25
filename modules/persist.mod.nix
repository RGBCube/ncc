{
  flake.nixosModules.persist =
    { lib, config, ... }:
    let
      inherit (lib.attrsets) listToAttrs;
      inherit (lib.lists) map;
      inherit (lib.modules) mkIf;
      inherit (lib.options) mkOption;
      inherit (lib.strings) removePrefix replaceStrings;
      inherit (lib.types) listOf path;
    in
    {
      options.persist = mkOption {
        type = listOf path;
        default = [ ];
        description = "Paths to persist as bcachefs subvolumes under the root filesystem.";
      };

      config = mkIf (config.persist != [ ]) {
        disko.devices.bcachefs_filesystems."root".subvolumes =
          config.persist
          |> map (mountpoint: {
            name =
              mountpoint
              |> removePrefix "/"
              |> replaceStrings [ "/" ] [ "-" ];
            value.mountpoint = mountpoint;
          })
          |> listToAttrs;
      };
    };
}
