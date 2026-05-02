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
        mergeAttrsList
        ;
      inherit (lib.lists)
        filter
        map
        optional
        singleton
        ;
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
              ${mountpoint |> removePrefix "/" |> replaceStrings [ "/" ] [ "-" ]} = { inherit mountpoint; };
            })
            |> mergeAttrsList;
        })

        {
          fileSystems =
            config.disko.devices.bcachefs_filesystems
            |> concatMapAttrs (
              _: filesystem:
              genAttrs
                (
                  singleton filesystem.mountpoint ++ (filesystem.subvolumes |> attrValues |> catAttrs "mountpoint")
                  |> filter (mp: mp != null)
                )
                (const {
                  options =
                    singleton "lazytime"
                    ++ optional (
                      filesystem.passwordFile != null
                    ) "x-systemd.requires-mounts-for=${dirOf filesystem.passwordFile}";
                })
            );

          # Override each filesystem & mountpoint unlock script to use the passwordFile rather than prompting.
          boot.initrd.systemd.services =
            config.disko.devices.bcachefs_filesystems
            |> filterAttrs (_: filesystem: filesystem.passwordFile != null)
            |> concatMapAttrs (
              _: filesystem:
              genAttrs
                (
                  singleton filesystem.mountpoint ++ (filesystem.subvolumes |> attrValues |> catAttrs "mountpoint")
                  |> filter (mountpoint: mountpoint != null)
                  |> map (mountpoint: "unlock-bcachefs-${escapeSystemdPath mountpoint}")
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
                      --file ${filesystem.passwordFile} \
                      /dev/disk/by-uuid/${filesystem.uuid}
                  '';
                })
            );
        }

      ];
    };
}
