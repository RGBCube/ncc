{
  homeModules.w3m-ddg =
    { lib, pkgs, ... }:
    let
      inherit (lib.meta) getExe;

      package = pkgs.w3m;
    in
    {
      programs.nushell.aliases.ddg = # sh
        ''${getExe package} lite.duckduckgo.com'';

      packages = [
        package
      ];
    };
}
