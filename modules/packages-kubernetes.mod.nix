{
  flake.homeModules.packages-kubernetes =
    { pkgs, ... }:
    {
      packages = [
        pkgs.kubectl
        pkgs.kubernetes-helm
      ];
    };
}
