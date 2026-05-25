{
  flake.nixosModules.persist =
    {
      lib,
      config,
      utils,
      ...
    }:
    let
      inherit (lib.attrsets)
        genAttrs
        genAttrs'
        mapAttrsRecursive
        nameValuePair
        optionalAttrs
        recursiveUpdate
        ;
      inherit (lib.generators) toINI;
      inherit (lib.lists) head;
      inherit (lib.modules) mkIf mkMerge;
      inherit (lib.options) mkEnableOption mkOption;
      inherit (lib.types)
        listOf
        nullOr
        path
        str
        ;
      inherit (utils) escapeSystemdPath;
    in
    {
      options.persist = {
        enable = mkEnableOption "bcachefs-backed persistence";

        filesystemName = mkOption {
          type = str;
          default = "persist";
          description = "Name of the filesystem.";
        };

        passwordFile = mkOption {
          type = nullOr path;
          default = null;
          description = "Path to the password file.";
        };

        extraFormatArgs = mkOption {
          type = listOf str;
          default = [
            "--compression=zstd:9"
            "--background_compression=zstd:9"
            "--block_size=4096"
          ];
          description = "Extra arguments passed to bcachefs format.";
        };

        mountpoints = mkOption {
          type = listOf path;
          default = [ ];
          description = "Directories to persist under the root filesystem.";
        };

        mountOptions = mkOption {
          type = listOf str;
          default = [
            "lazytime"
          ];
          description = "Mount options applied to each mountpoint.";
        };
      };

      config = mkIf config.persist.enable (mkMerge [
        {
          disko.devices.nodev."root" = {
            fsType = "tmpfs";
            mountpoint = "/";
            mountOptions = [
              "defaults"
              "size=25%"
              "mode=755"
            ];
          };

          disko.devices.bcachefs_filesystems.${config.persist.filesystemName} = {
            type = "bcachefs_filesystem";

            inherit (config.persist)
              passwordFile
              extraFormatArgs
              mountOptions
              ;

            subvolumes = genAttrs config.persist.mountpoints (mountpoint: {
              inherit mountpoint;
              inherit (config.persist) mountOptions;
            });
          };

          # Suppress nixpkgs's per-mountpoint unlock services.
          boot.initrd.systemd.suppressedUnits = mkIf (config.persist.passwordFile != null) (
            config.persist.mountpoints
            |> map (mountpoint: "unlock-bcachefs-${escapeSystemdPath mountpoint}.service")
          );
        }

        (
          let
            unitsFor =
              root:
              let
                unitName = mountpoint: "${escapeSystemdPath "${root}${mountpoint}"}.mount";
                anchor = head config.persist.mountpoints;
              in
              genAttrs' config.persist.mountpoints (
                mountpoint:
                nameValuePair (unitName mountpoint) {
                  overrideStrategy = "asDropin";
                  text =
                    toINI { }
                    <|
                      recursiveUpdate
                        # Order every mount after the first mount. The first mount
                        # will do an exclusive open of the filesystem, later mounts
                        # will be able to reuse the existing object and not lock.
                        (optionalAttrs (mountpoint != anchor) {
                          Unit.After = unitName anchor;
                        })
                        (
                          optionalAttrs (config.persist.passwordFile != null) {
                            Unit.RequiresMountsFor = "${root}${config.persist.passwordFile}";
                            Mount.StandardInput = "file:${root}${config.persist.passwordFile}";
                          }
                        );
                }
              );
          in
          {
            boot.initrd.systemd.units = unitsFor "/sysroot";
            systemd.units = unitsFor "";
          }
        )
      ]);
    };
}
