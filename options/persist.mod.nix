{
  flake.nixosModules.persist =
    {
      lib,
      config,
      utils,
      ...
    }:
    let
      inherit (lib.attrsets) genAttrs mergeAttrsList optionalAttrs;
      inherit (lib.generators) toINI;
      inherit (lib.lists) elemAt imap0 singleton;
      inherit (lib.modules) mkIf;
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
        enable = mkEnableOption "bcachefs subvolume persistence";

        filesystemName = mkOption {
          type = str;
          default = "persist";
          description = "Name of the filesystem.";
        };

        passwordFile = mkOption {
          type = nullOr path;
          default = null;
          description = "Path to the passphrase file.";
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

        mountpoint = mkOption {
          type = path;
          default = "/media/${config.persist.filesystemName}";
          description = "Mountpoint for the filesystem.";
        };

        subvolumes = mkOption {
          type = listOf path;
          default = [ ];
          description = "Directories to persist as subvolumes under the root filesystem.";
        };

        mountOptions = mkOption {
          type = listOf str;
          default = [
            "lazytime"
          ];
          description = "Mount options applied to the filesystem and every subvolume.";
        };
      };

      config = mkIf config.persist.enable {
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
            mountpoint
            passwordFile
            extraFormatArgs
            mountOptions
            ;

          subvolumes = genAttrs config.persist.subvolumes (mountpoint: {
            inherit mountpoint;
            inherit (config.persist) mountOptions;
          });
        };

        # Suppress nixpkgs's per-mountpoint unlock services.
        boot.initrd.systemd.suppressedUnits = mkIf (config.persist.passwordFile != null) (
          singleton config.persist.mountpoint ++ config.persist.subvolumes
          |> map (mountpoint: "unlock-bcachefs-${escapeSystemdPath mountpoint}.service")
        );

        # Serialize per-mountpoint .mount units via After= chain. mount.bcachefs
        # opens the device with BLK_OPEN_EXCL, parallel scans across subvolume
        # mount units race and lose with EBUSY.
        boot.initrd.systemd.units = mkIf (config.persist.passwordFile != null) (
          let
            mountpoints = singleton config.persist.mountpoint ++ config.persist.subvolumes;
            unitName = mountpoint: "sysroot-${escapeSystemdPath mountpoint}.mount";
          in
          mountpoints
          |> imap0 (
            index: mountpoint: {
              ${unitName mountpoint} = {
                overrideStrategy = "asDropin";
                text = toINI { } {
                  Unit = {
                    RequiresMountsFor = "/sysroot${config.persist.passwordFile}";
                  }
                  // optionalAttrs (index > 0) {
                    After = unitName (elemAt mountpoints (index - 1));
                  };

                  Mount.StandardInput = "file:/sysroot${config.persist.passwordFile}";
                };
              };
            }
          )
          |> mergeAttrsList
        );
      };
    };
}
