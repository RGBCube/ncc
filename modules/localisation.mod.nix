{ self, ... }:
{
  flake.darwinModules.default = self.darwinModules.localisation;
  flake.darwinModules.localisation = {
    system.defaults.NSGlobalDomain = {
      AppleICUForce24HourTime = true;

      AppleMeasurementUnits = "Centimeters";
      AppleMetricUnits = 1;
      AppleTemperatureUnit = "Celsius";
    };
  };

  flake.nixosModules.default = self.nixosModules.localisation;
  flake.nixosModules.localisation =
    { pkgs, ... }:
    {
      i18n.defaultLocale = "C.UTF-8";
    };

  flake.homeModules.default = self.homeModules.localisation;
  flake.homeModules.localisation =
    { osConfig, lib, ... }:
    let
      inherit (lib.modules) mkIf;
    in
    {
      xdg.config.files."xkb/symbols/tr-swapped-i" = mkIf osConfig.nixpkgs.hostPlatform.isLinux {
        text =
          # rs
          ''
            default partial
            xkb_symbols "basic" {
              include "tr(basic)"

              name[Group1]="Turkish (i and ı swapped)";

              key <AC11>  { type[group1] = "FOUR_LEVEL_SEMIALPHABETIC", [ idotless, Iabovedot,  paragraph , none      ]};
              key <AD08>  { type[group1] = "FOUR_LEVEL_SEMIALPHABETIC", [ i       , I        ,  apostrophe, dead_caron ]};
            };
          '';
      };
    };
}
