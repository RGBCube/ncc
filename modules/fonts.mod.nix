{ self, ... }:
{
  flake.nixosModules.desktop = self.nixosModules.fonts;
  flake.nixosModules.fonts =
    { config, lib, pkgs, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      console = {
        earlySetup = true;
        font = "Lat2-Terminus16";
        packages = singleton pkgs.terminus_font;
      };

      fonts.packages = [
        config.theme.font.sans.package
        config.theme.font.mono.package

        pkgs.noto-fonts
        pkgs.noto-fonts-cjk-sans
        pkgs.noto-fonts-lgc-plus
        pkgs.noto-fonts-emoji
      ];
    };

  flake.nixosModules.server = self.nixosModules.fonts-disable;
  flake.nixosModules.fonts-disable = {
    fonts.fontconfig.enable = false;
  };
}
