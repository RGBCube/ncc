{
  homeModules.vivid =
    { lib, pkgs, ... }:
    let
      inherit (lib.meta) getExe;
      inherit (lib.strings) readFile;
    in
    {
      packages = [
        pkgs.vivid
      ];

      # Yes, IFD. Deal with it.
      environment.sessionVariables.LS_COLORS =
        readFile
        <| pkgs.runCommand "ls_colors.txt" { } ''
          ${getExe pkgs.vivid} generate gruvbox-dark-hard > $out
        '';
    };
}
