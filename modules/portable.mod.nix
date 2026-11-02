{
  flake.nixosModules.portable =
    { config, lib, ... }:
    let
      inherit (lib.modules) mkForce;
    in
    {
      # HARDWARE
      hardware.enableAllHardware = true;
      hardware.enableAllFirmware = true;

      nixpkgs.allowedUnfreePackages = [
        "broadcom-bt-firmware"
        "b43-firmware"
        "xone-dongle-firmware"
        "facetimehd-calibration"
        "facetimehd-firmware"
      ];

      # BOOT
      # Take your greasy hands off my NVRAM!
      boot.loader.efi.canTouchEfiVariables = mkForce false;

      # STORAGE
      persist.extraFormatArgs = [
        # 15 is the max.
        "--compression=zstd:15"
        "--background_compression=zstd:15"
      ];

      disko.devices.disk."main" = {
        type = "disk";

        content.type = "gpt";

        content.partitions."boot" = {
          priority = 100;
          size = "1G";
          type = "EF00";

          content.type = "filesystem";
          content = {
            format = "vfat";
          };
        };

        content.partitions."bcachefs" = {
          priority = 200;
          size = "100%";

          content.type = "bcachefs";
          content = {
            filesystem = config.persist.filesystemName;
            label = "usb.usb0";
          };
        };
      };
    };
}
