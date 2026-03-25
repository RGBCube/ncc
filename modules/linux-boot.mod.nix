{
  flake.nixosModules.boot =
    {
      boot.initrd.systemd.enable = true;

      boot.loader.systemd-boot = {
        enable = true;
        editor = false;
      };

      boot.loader.efi.canTouchEfiVariables = true;

      boot.supportedFilesystems = {
        bcachefs = true;
      };
    };
}
