{
  flake.nixosModules.bluetooth-gui =
    { config, lib, ... }:
    let
      inherit (lib.modules) mkIf;
    in
    {
      services.blueman.enable = mkIf (config.hardware.report.hardware.bluetooth or [] != []) true;
    };

  # hardware.bluetooth.enable is set by nixos-facter.
  flake.nixosModules.bluetooth =
    { config, lib, ... }:
    let
      inherit (lib.modules) mkIf;
    in
    {
      hardware.bluetooth.powerOnBoot = mkIf (config.hardware.report.hardware.bluetooth or [] != []) true;
    };
}
