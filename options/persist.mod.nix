{
  flake.nixosModules.persist =
    {
      lib,
      config,
      utils,
      ...
    }:
    let
      inherit (lib.attrsets) genAttrs mergeAttrsList;
      inherit (lib.lists) map optional singleton;
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkForce mkIf;
      inherit (lib.options) mkEnableOption mkOption;
      inherit (lib.strings) removePrefix replaceStrings;
      inherit (lib.trivial) const;
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

        mountOptions = mkOption {
          type = listOf str;
          default = [
            "lazytime"
          ]
          ++ optional (
            config.persist.passwordFile != null
          ) "x-systemd.requires-mounts-for=${dirOf config.persist.passwordFile}";
          description = "Mount options applied to the filesystem and every subvolume.";
        };

        paths = mkOption {
          type = listOf path;
          default = [ ];
          description = "Paths to persist as subvolumes under the root filesystem.";
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

          subvolumes =
            config.persist.paths
            |> map (mountpoint: {
              ${mountpoint |> removePrefix "/" |> replaceStrings [ "/" ] [ "-" ]} = {
                inherit mountpoint;
                inherit (config.persist) mountOptions;
              };
            })
            |> mergeAttrsList;
        };

        # Override the nixpkgs-generated unlock script (nixos/modules/tasks/filesystems/bcachefs.nix) to read passwordFile rather than systemd-ask-password.
        boot.initrd.systemd.services = mkIf (config.persist.passwordFile != null) (
          genAttrs
            (
              singleton config.persist.mountpoint ++ config.persist.paths
              |> map (mp: "unlock-bcachefs-${escapeSystemdPath mp}")
            )
            (const {
              script = mkForce /* bash */ ''
                # bcachefs-tools defaults to `--keyring user` (@u), but the kernel's
                # `request_key()` searches thread -> process -> session keyrings. @u is
                # only reachable via the user-session keyring (@us) fallback, which is
                # skipped when a session keyring (@s) exists, which is the case in
                # initrd systemd and SSH. Without `--keyring session` mount fails with
                # ENOKEY ("Required key not available").
                ${getExe config.boot.bcachefs.package} unlock \
                  --keyring session \
                  --file ${config.persist.passwordFile} \
                  /dev/disk/by-uuid/${
                    config.disko.devices.bcachefs_filesystems.${config.persist.filesystemName}.uuid
                  }
              '';
            })
        );
      };
    };
}
