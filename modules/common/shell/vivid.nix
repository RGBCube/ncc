{ lib, pkgs, ... }: let
  inherit (lib) getExe readFile;
in {
  # Yes, IFD. Deal with it.
  environment.variables.LS_COLORS = readFile <|
    pkgs.runCommand "ls_colors.txt" {} ''
      ${getExe pkgs.vivid} generate gruvbox-dark-hard > $out
    '';
}
