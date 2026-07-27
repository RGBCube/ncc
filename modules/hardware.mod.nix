{ inputs, self, ... }:
{
  flake.nixosModules.hardware = self.nixosModules.hardware-report;
  flake.nixosModules.hardware-report =
    { lib, ... }:
    let
      inherit (lib.modules) mkAliasOptionModule;
    in
    {
      imports = [
        inputs.nixos-facter.nixosModules.facter

        (mkAliasOptionModule [ "hardware" "reportPath" ] [ "facter" "reportPath" ])
        (mkAliasOptionModule [ "hardware" "report" ] [ "facter" "report" ])
      ];
    };

  flake.nixosModules.desktop.imports = [
    self.nixosModules.bluetooth-gui
    self.nixosModules.sound
  ];
  flake.nixosModules.bluetooth-gui =
    { config, lib, ... }:
    let
      inherit (lib.modules) mkIf;
    in
    {
      services.blueman.enable = mkIf (config.hardware.report.hardware.bluetooth or [ ] != [ ]) true;
    };

  flake.nixosModules.sound =
    { config, lib, ... }:
    let
      inherit (lib.modules) mkIf;
    in
    {
      config = mkIf (config.hardware.report.hardware.sound or [ ] != [ ]) {
        security.rtkit.enable = true;

        services.pipewire = {
          enable = true;

          alsa.enable = true;
          alsa.support32Bit = true;

          pulse.enable = true;
        };
      };
    };
}
