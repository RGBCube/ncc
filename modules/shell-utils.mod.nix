{
  homeModules.shell-utils = { pkgs, ...}: {
    packages = [
      pkgs.moreutils
      pkgs.jc
      pkgs.tokei
    ];
  };
}
