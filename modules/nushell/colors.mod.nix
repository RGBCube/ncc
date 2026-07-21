{ self, ... }:
{

  flake.homeModules.shell = self.homeModules.colors;
  flake.homeModules.colors =
    { lib, pkgs, ... }:
    let
      inherit (lib.meta) getExe;
      inherit (lib.lists) singleton;

      lsColors = pkgs.runCommand "ls_colors.txt" { } ''
        ${getExe pkgs.vivid} generate gruvbox-dark-hard > $out
      '';
    in
    {
      packages = singleton pkgs.vivid;

      xdg.config.files."nushell/settings.nu".value = {
        color_config.row_index = "light_yellow_bold";
        color_config.header = "light_yellow_bold";
      };

      xdg.config.files."nushell/config.nu".text = "source ${
        pkgs.writeText "colors.nu" /* nu */ ''
          $env.LS_COLORS = open --raw ${lsColors}

          $env.config.color_config.bool = {||
            if $in {
              "light_green_bold"
            } else {
              "light_red_bold"
            }
          }

          $env.config.color_config.string = {||
            if $in =~ "^(#|0x)[a-fA-F0-9]+$" {
              $in | str replace "0x" "#"
            } else {
              "white"
            }
          }
        ''
      }";
    };
}
