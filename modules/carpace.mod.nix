{
  flake.homeModules.carapace =
    { pkgs, lib, ... }:
    let
      inherit (lib.meta) getExe;
    in
    {
      # CARAPACE
      packages = [
        pkgs.carapace
        pkgs.inshellisense
        pkgs.zsh
        pkgs.fish
        pkgs.bash
      ];

      environment.sessionVariables.CARAPACE_BRIDGES = "inshellisense,carapace,zsh,fish,bash";

      programs.nushell.extraConfig = /* nu */ ''
        source ${
          pkgs.runCommand "carapace.nu" { } /* bash */ ''
            ${getExe pkgs.carapace} _carapace nushell > $out
          ''
        }
      '';
    };
}
