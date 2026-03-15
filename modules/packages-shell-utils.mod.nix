{
  flake.homeModules.packages-shell-utils =
    { pkgs, ... }:
    {
      packages = [
        pkgs.asciinema
        pkgs.fastfetch
        pkgs.fd
        pkgs.jc
        pkgs.moreutils
        pkgs.openssl
        pkgs.p7zip
        pkgs.rclone
        pkgs.sd
        pkgs.timg
        pkgs.tokei
        pkgs.uutils-coreutils-noprefix
        pkgs.yazi
      ];
    };
}
