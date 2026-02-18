{
  flake.homeModules.keepassxc =
    {
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) singleton;
    in
    {
      packages = singleton pkgs.keepassxc;
    };
}
