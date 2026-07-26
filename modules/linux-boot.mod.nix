{ self, ... }: {
  flake.nixosModules.default = self.nixosModules.linux-boot;
  flake.nixosModules.linux-boot = {
    boot.initrd.systemd.enable = true;

    boot.loader = {
      systemd-boot.enable = true;
      systemd-boot.editor = false;

      # Avoid unnecessary modesets and paints.
      systemd-boot.consoleMode = "keep";
      timeout = 0;

      efi.canTouchEfiVariables = true;
    };
  };
}
