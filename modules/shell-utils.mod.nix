{
  homeModules.shell-utils = { pkgs, ...}: {
    packages = [
      pkgs.fd
      pkgs.jc
      pkgs.moreutils
      pkgs.tokei
      pkgs.uutils-coreutils-noprefix
      pkgs.yazi
    ];
  };
}
