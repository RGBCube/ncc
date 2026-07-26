{ self, ... }:
{
  flake.nixosModules.desktop = self.nixosModules.fonts;
  flake.nixosModules.fonts =
    { config, pkgs, ... }:
    {
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
