{ config, lib, pkgs, ... }: let
  inherit (lib) const genAttrs merge mkIf;
in merge {
  console.keyMap = pkgs.writeText "trq-swapped-i.map" /* hs */ ''
    include "${pkgs.kbd}/share/keymaps/i386/qwerty/trq.map"

    keycode 23 = i
    	altgr       keycode 23 = +icircumflex
    	altgr shift keycode 23 = +Icircumflex

    keycode 40 = +dotlessi +Idotabove
  '';

  home-manager.sharedModules = [{
    xdg.configFile."xkb/symbols/tr-swapped-i".text = /* rs */ ''
      default partial
      xkb_symbols "basic" {
        include "tr(basic)"

        name[Group1]="Turkish (i and ı swapped)";

        key <AC11>  { type[group1] = "FOUR_LEVEL_SEMIALPHABETIC", [ idotless, Iabovedot,  paragraph , none      ]};
        key <AD08>  { type[group1] = "FOUR_LEVEL_SEMIALPHABETIC", [ i       , I        ,  apostrophe, dead_caron ]};
      };
    '';
  }];

  i18n.defaultLocale = "C.UTF-8";
} <| mkIf config.isDesktop {
  i18n.extraLocaleSettings = genAttrs [
    "LC_ADDRESS"
    "LC_IDENTIFICATION"
    "LC_MEASUREMENT"
    "LC_MONETARY"
    "LC_NAME"
    "LC_NUMERIC"
    "LC_PAPER"
    "LC_TELEPHONE"
    "LC_TIME"
  ] <| const "tr_TR.UTF-8";
}

