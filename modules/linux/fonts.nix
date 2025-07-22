{ config, lib, pkgs, ... }: let
  inherit (lib) disabled merge mkIf;
in merge

(mkIf config.isDesktop {
  console = {
    earlySetup = true;
    font       = "Lat2-Terminus16";
    packages   = [ pkgs.terminus_font ];
  };

  fonts.packages = [
    config.theme.font.sans.package
    config.theme.font.mono.package

    pkgs.noto-fonts
    pkgs.noto-fonts-cjk-sans
    pkgs.noto-fonts-lgc-plus
    pkgs.noto-fonts-emoji
  ];
})

(mkIf config.isServer {
  fonts.fontconfig = disabled;
})
