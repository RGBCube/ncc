{
  homeModules.wisdon = { pkgs, ... }: {
    packages = [
      pkgs.cowsay
      (pkgs.fortune.override { withOfffensive = true; })
    ];
  };
}
