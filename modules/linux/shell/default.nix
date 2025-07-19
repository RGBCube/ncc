{ config, lib, pkgs, ... }: let
  inherit (lib) concatStringsSep;
in {
  users.defaultUserShell = pkgs.crash;

  environment.sessionVariables.SHELLS = config.shellsByPriority
    |> map (drv: "${drv}${drv.shellPath}")
    |> concatStringsSep ":";
}
