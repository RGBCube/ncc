{
  flake.homeModules.packages-wisdom =
    { pkgs, ... }:
    {
      packages = [
        pkgs.cowsay
        (pkgs.fortune.override { withOffensive = true; })
      ];
    };
}
