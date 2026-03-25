{
  flake.nixosModules.sound =
    { config, lib, ... }:
    let
      inherit (lib.modules) mkIf;
    in
    {
      config = mkIf (config.hardware.report.hardware.sound or [] != []) {
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
