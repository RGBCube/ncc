{
  flake.homeModules.ripgrep =
    { lib, pkgs, ... }:
    let
      inherit (lib.generators) toCliArgumentList;
    in
    {
      packages = [
        pkgs.ripgrep
      ];

      xdg.config.files."ripgrep/config".generator = toCliArgumentList;
      xdg.config.files."ripgrep/config".value = {
        line-number = true;
        smart-case = true;
      };
    };
}
