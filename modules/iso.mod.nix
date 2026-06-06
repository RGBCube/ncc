{ inputs, ... }:
{
  flake.nixosModules.iso =
    {
      config,
      lib,
      ...
    }:
    let
      inherit (lib.lists) singleton;
    in
    {
      imports = singleton <| inputs.nixpkgs + /nixos/modules/installer/cd-dvd/iso-image.nix;

      isoImage.makeEfiBootable = true;
      isoImage.makeUsbBootable = true;
      isoImage.storeContents = singleton config.system.build.toplevel;

      hardware.enableAllHardware = true;

      nixpkgs.allowedUnfreePackages = [
        "broadcom-bt-firmware"
        "b43-firmware"
        "xone-dongle-firmware"
        "facetimehd-calibration"
        "facetimehd-firmware"
      ];

      hardware.enableAllFirmware = true;

      users.users.root.initialHashedPassword = "";
      services.getty.autologinUser = "root";
    };
}
