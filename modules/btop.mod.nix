{
  flake.homeModules.btop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.generators) toKeyValue;

      color_theme = "base16";
    in
    {
      packages = [
        pkgs.btop
      ];

      xdg.config.files."btop/themes/${color_theme}.theme".text = config.theme.btopTheme;

      xdg.config.files."btop/btop.conf".generator = toKeyValue { };
      xdg.config.files."btop/btop.conf".value = {
        inherit color_theme;
        rounded_corners = config.theme.cornerRadius > 0;
      };
    };
}
