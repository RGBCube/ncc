{
  flake.nixosModules.bluetooth-gui = {
    services.blueman.enable = true;
  };

  flake.nixosModules.bluetooth = {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };
}
