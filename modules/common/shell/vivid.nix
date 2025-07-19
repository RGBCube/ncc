{ lib, pkgs, ... }: let
  inherit (lib) getExe mkConst;

  lsColors = pkgs.runCommand "ls_colors.txt" {} ''
    ${getExe pkgs.vivid} generate gruvbox-dark-hard > $out
  '';
in {
  options.environment.ls-colors = mkConst lsColors;
}
