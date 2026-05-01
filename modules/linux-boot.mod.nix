{
  flake.nixosModules.boot = {
    boot.initrd.systemd.enable = true;

    boot.loader.systemd-boot = {
      enable = true;
      # editor = false; # Security Theather. Hell, Security Cinema even.
    };

    boot.loader.efi.canTouchEfiVariables = true;

    boot.supportedFilesystems = {
      bcachefs = true;
    };
  };
}
