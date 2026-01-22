{ config, lib, pkgs, ... }: let
  inherit (lib) optionals;
in {
  unfree.allowedNames = [ "claude-code" ];

  environment.systemPackages = [
    pkgs.asciinema
    pkgs.cowsay
    pkgs.curl
    pkgs.dig
    pkgs.doggo
    pkgs.eza
    pkgs.fastfetch
    pkgs.fd
    pkgs.hyperfine
    pkgs.jc
    pkgs.moreutils
    pkgs.openssl
    pkgs.p7zip
    pkgs.pstree
    pkgs.rsync
    pkgs.sd
    pkgs.timg
    pkgs.tokei
    pkgs.typos
    pkgs.uutils-coreutils-noprefix
    pkgs.xh
    pkgs.yazi
    pkgs.yt-dlp
    (pkgs.fortune.override { withOffensive = true; })
  ] ++ optionals config.isLinux [
    pkgs.traceroute
    pkgs.usbutils
    pkgs.strace
  ] ++ optionals config.isDesktop [
    pkgs.claude-code

    pkgs.clang
    pkgs.clang-tools
    pkgs.deno
    pkgs.gh
    pkgs.go
    pkgs.lld
    pkgs.zig

    pkgs.qbittorrent
  ] ++ optionals (config.isLinux && config.isDesktop) [
    pkgs.haruna

    pkgs.thunderbird

    pkgs.whatsapp-for-linux

    pkgs.element-desktop
    pkgs.zulip
    pkgs.fractal

    pkgs.obs-studio

    pkgs.krita

    pkgs.libreoffice

    pkgs.en_US
    pkgs.en_GB-ize
  ] ++ optionals (config.isDarwin && config.isDesktop) [
    pkgs.iina
  ];
}
