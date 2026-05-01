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
        attrValues
        catAttrs
        concatMapAttrs
        filterAttrs
        genAttrs
        listToAttrs
        ;
      inherit (lib.lists) filter map optional;
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkForce mkIf mkMerge;
      inherit (lib.options) mkEnableOption mkOption;
      inherit (lib.strings) removePrefix replaceStrings;
      inherit (lib.trivial) const;
      inherit (lib.types) listOf path;
      inherit (utils) escapeSystemdPath;
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

      config = mkMerge [
        (mkIf (config.persist.enable && config.persist.paths != [ ]) {
          disko.devices.bcachefs_filesystems."persist".subvolumes =
            config.persist.paths
            |> map (mountpoint: {
              name = mountpoint |> removePrefix "/" |> replaceStrings [ "/" ] [ "-" ];
              value.mountpoint = mountpoint;
            })
            |> listToAttrs;
        })

        {
          # Override each filesystem & mountpoint unlock script to use the passwordFile rather than prompting.
          boot.initrd.systemd.services =
            config.disko.devices.bcachefs_filesystems
            |> filterAttrs (_: filesystem: filesystem.passwordFile != null)
            |> concatMapAttrs (
              _: filesystem:
              let
                mountpoints =
                  optional (filesystem.mountpoint != null) filesystem.mountpoint
                  ++ (
                    filesystem.subvolumes
                    |> attrValues
                    |> catAttrs "mountpoint"
                    |> filter (mountpoint: mountpoint != null)
                  );

                unlockScript = /* bash */ ''
                  # bcachefs-tools defaults to `--keyring user` (@u), but the kernel's
                  # `request_key()` searches thread -> process -> session keyrings. @u is
                  # only reachable via the user-session keyring (@us) fallback, which is
                  # skipped when a session keyring (@s) exists, which is the case in
                  # initrd systemd and SSH. Without `--keyring session` mount fails with
                  # ENOKEY ("Required key not available").
                  ${getExe config.boot.bcachefs.package} unlock \
                    --keyring session \
                    --file ${filesystem.passwordFile} \
                    /dev/disk/by-uuid/${filesystem.uuid}
                '';
              in
              genAttrs (mountpoints |> map (mountpoint: "unlock-bcachefs-${escapeSystemdPath mountpoint}"))
                (const {
                  script = mkForce unlockScript;
                })
            );
        }
      ];
    };
}
