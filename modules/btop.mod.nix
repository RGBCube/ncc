{
  homeModules.btop =
    { config, lib, pkgs, ... }:
    let
      inherit (lib.generators) toKeyValue;
      
      color_theme = "base16";
    in
    {
      packages = [
        pkgs.btop
      ];

      xdg.config.file."btop/themes/${color_theme}.theme".text = config.theme.btopTheme;

      xdg.config.file."btop/btop.conf".generator = toKeyValue { };
      xdg.config.file."btop/btop.conf".value = {
        inherit color_theme;
        rounded_corners = config.theme.cornerRadius > 0;
      };
    };
}
