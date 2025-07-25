{ config, lib, pkgs, ... }: let
  inherit (lib) concatStringsSep const flatten getAttr mapAttrsToList unique;
in {
  users.defaultUserShell = pkgs.crash;

  # TODO: This should be a per-user session variable. But we can't set
  # a home-manager session variable because that's initialized by the
  # shell itself! Lol.
  environment.sessionVariables.SHELLS = config.home-manager.users
  |> mapAttrsToList (const <| getAttr "shellsByPriority")
  |> flatten
  |> map (drv: "${drv}${drv.shellPath}")
  |> unique
  |> concatStringsSep ":";
}
