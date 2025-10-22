{
  homeModules.yak-shaving = { pkgs, ... }: {
    packages = [
      pkgs.hyperfine
      pkgs.typos
      pkgs.tokei
    ];
  };
}
