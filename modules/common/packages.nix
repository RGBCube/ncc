{ config, lib, pkgs, ... }: let
  inherit (lib) attrValues optionalAttrs;
in {
  unfree.allowedNames = [ "claude-code" ];

  environment.systemPackages = attrValues <| {
    inherit (pkgs)
      asciinema
      cowsay
      curlHTTP3
      dig
      doggo
      eza
      fastfetch
      fd
      hyperfine
      jc
      moreutils
      openssl
      p7zip
      pstree
      rsync
      sd
      timg
      tokei
      typos
      uutils-coreutils-noprefix
      xh
      yazi
      yt-dlp
    ;

    fortune = pkgs.fortune.override { withOffensive = true; };
  } // optionalAttrs config.isLinux {
    inherit (pkgs)
      traceroute
      usbutils
      strace
    ;
  } // optionalAttrs config.isDesktop {
    inherit (pkgs)
      claude-code

      clang_16
      clang-tools_16
      deno
      gh
      go
      lld
      zig

      qbittorrent
    ;
  } // optionalAttrs (config.isLinux && config.isDesktop) {
    inherit (pkgs)
      thunderbird

      whatsapp-for-linux

      element-desktop
      zulip
      fractal

      obs-studio

      krita

      libreoffice
    ;

    inherit (pkgs.hunspellDicts)
      en_US
      en_GB-ize
    ;
  };
}
