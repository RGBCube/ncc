{ self, ... }:
{
  flake.nixosModules.boot = self.nixosModules.linux-boot-redundancy;
  flake.nixosModules.linux-boot-redundancy =
    {
      lib,
      config,
      options,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) attrValues;
      inherit (lib.lists)
        concatMap
        filter
        head
        imap0
        tail
        ;
      inherit (lib.meta) getExe getExe';
      inherit (lib.modules) mkForce mkIf;
      inherit (lib.strings) hasInfix toJSON toUpper;

      paths =
        config.disko.devices.disk
        |> attrValues
        |> concatMap (
          { content, ... }:
          content.partitions
          |> attrValues
          |> filter (partition: partition.type == "EF00")
          |> map (partition: partition.device)
        )
        |> imap0 (
          index: source: {
            inherit source;
            destination = "/run/boot-${toString index}";
            label = "Linux Boot Manager Mirror (${baseNameOf source})";
          }
        );

      primary = head paths // {
        label = "Linux Boot Manager";
      };
      secondary = tail paths;

      mount = getExe' pkgs.util-linux "mount";
      umount = getExe' pkgs.util-linux "umount";
      lsblk = getExe' pkgs.util-linux "lsblk";
      sync = getExe' pkgs.coreutils "sync";
    in
    {
      config = mkIf (paths != [ ]) {
        boot.loader.efi.efiSysMountPoint = primary.destination;

        system.build.installBootLoader =
          mkForce
          <| pkgs.writers.writeNu "install-redundant-boot" /* nu */ ''
            def main [toplevel: path] {
              let primary = r###'${toJSON primary}'### | from json
              let secondary = r###'${toJSON secondary}'### | from json

              try {
                ^${mount} --mkdir --options fmask=0077,dmask=0077 $primary.source $primary.destination

                # INSTALL BOOTLOADER
                ^${
                  options.system.build.definitionsWithLocations
                  |> filter (
                    { file, value }: value ? installBootLoader && !hasInfix "linux-boot-redundancy.mod.nix" file
                  )
                  |> head
                  |> ({ value, ... }: value.installBootLoader)
                } $toplevel

                for entry in $secondary {
                  ^${mount} --mkdir --options fmask=0077,dmask=0077 $entry.source $entry.destination
                  ^${getExe pkgs.rclone} sync $primary.destination $entry.destination
                  ^${sync} --file-system $entry.destination
                  ^${umount} $entry.destination

                  let existing_slot = (^${getExe pkgs.efibootmgr}
                    | lines
                    | parse --regex r###'^Boot(?P<slot>[0-9A-Fa-f]{4})\*?\s(?P<label>[^\t]*)\t.*$'###
                    | where label == $entry.label
                    | get 0?.slot)
                  if ($existing_slot | is-not-empty) {
                    ^${getExe pkgs.efibootmgr} --bootnum $existing_slot --delete-bootnum
                  }

                  (^${getExe pkgs.efibootmgr}
                    --create
                    --disk $"/dev/(^${lsblk} --noheadings --output PKNAME $entry.source | str trim)"
                    --part (^${lsblk} --noheadings --output PARTN $entry.source | str trim)
                    --label $entry.label
                    --loader '\EFI\BOOT\BOOT${toUpper pkgs.stdenv.hostPlatform.efiArch}.EFI')
                }

                let entries = ^${getExe pkgs.efibootmgr} | lines | parse --regex r###'^Boot(?P<slot>[0-9A-Fa-f]{4})\*?\s(?P<label>[^\t]*)\t.*$'###
                def "into slot" []: string -> any {
                  $entries | where label == $in | get 0?.slot
                }

                ^${getExe pkgs.efibootmgr} --bootorder (
                  [($primary.label | into slot)]
                  | append ($secondary | each {|entry| $entry.label | into slot })
                  | str join ","
                )

                ^${sync} --file-system $primary.destination
                ^${umount} $primary.destination
              } catch {|error|
                for thing in ([$primary] | append $secondary | reverse) {
                  try { ^${sync} --file-system $thing.destination }
                  try { ^${umount} $thing.destination }
                }

                error make { msg: $error.msg }
              }
            }
          '';
      };
    };
}
