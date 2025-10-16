{
  homeModules.tailscale-linux =
    { lib, pkgs, ... }:
    let
      inherit (lib.meta) getExe;

      package = getExe pkgs.tailscale;
    in
    {
      programs.nushell.aliases = {
        ts = "sudo ${package}";
      };

      packages = [
        package
      ];
    };

  homeModules.tailscale-darwin =
    { lib, pkgs, ... }:
    let
      inherit (lib.meta) getExe;

      package = getExe pkgs.tailscale;
    in
    {
      programs.nushell.aliases = {
        ts = package;
      };

      packages = [
        package
      ];
    };
}
