{ self, ... }:
{
  flake.homeModules.cli = self.homeModules.btop;
  flake.homeModules.btop =
    {
      osConfig,
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

      xdg.config.files."btop/themes/${color_theme}.theme".text = osConfig.theme.btopTheme;

      xdg.config.files."btop/btop.conf".generator = toKeyValue { };
      xdg.config.files."btop/btop.conf".value = {
        inherit color_theme;
        rounded_corners = osConfig.theme.cornerRadius > 0;
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
        # btop 1.4's Apple-Silicon GPU support crashes (SIGTRAP) in Cpu::draw via
        # an OOB read into the GPU vector when drawing GPU info on darwin.
        show_gpu_info = "Off";
      };
    };
}
