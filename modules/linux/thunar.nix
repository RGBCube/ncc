{ config, lib, pkgs, ... }: let
  inherit (lib) enabled merge mkIf;
in merge <| mkIf config.isDesktop {
  programs.thunar = enabled {
    plugins = [
      pkgs.xfce.thunar-archive-plugin
      pkgs.xfce.thunar-media-tags-plugin
      pkgs.xfce.thunar-volman
    ];
  };

  environment.systemPackages = [
    pkgs.ark
    pkgs.ffmpegthumbnailer
    pkgs.libgsf

    pkgs.xfce.tumbler
  ];
}
