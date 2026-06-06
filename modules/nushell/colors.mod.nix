{
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

      extraDependencies = singleton lsColors;

      programs.nushell.settings = {
        color_config.row_index = "light_yellow_bold";
        color_config.header = "light_yellow_bold";
      };

      # FIXME: Decomissioned until nh fixes their remote build
      # (to build with --eval-store auto --store <ssh> rather
      # than evaling drv then uploading it then building remotely)
      #
      # # Yes, IFD. Deal with it.
      # environment.sessionVariables.LS_COLORS = readFile lsColors;

      # Nushell-only workaround:
      programs.nushell.extraConfig = "source ${
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
      }\n";
    };
}
