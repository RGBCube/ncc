{
  darwinModules.localisation = {
    system.defaults.NSGlobalDomain = {
      AppleICUForce24HourTime = true;

      AppleMeasurementUnits = "Centimeters";
      AppleMetricUnits = 1;
      AppleTemperatureUnit = "Celsius";
    };
  };

  nixosModules.localisation =
    { pkgs, ... }:
    {
      console.keyMap =
        pkgs.writeText "trq-swapped-i.map" # hs
          ''
            include "${pkgs.kbd}/share/keymaps/i386/qwerty/trq.map"

            keycode 23 = i
            	altgr       keycode 23 = +icircumflex
            	altgr shift keycode 23 = +Icircumflex

            keycode 40 = +dotlessi +Idotabove
          '';

      i18n.defaultLocale = "C.UTF-8";
    };

  homeModules.localisation-linux = {
    xdg.config.file."xkb/symbols/tr-swapped-i".text = # rs
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
}
