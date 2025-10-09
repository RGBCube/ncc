let
  commonModule =
    { lib, pkgs, ... }:
    let
      inherit (lib.meta) getExe;

      package = pkgs.w3m;
    in
    {
      environment.systemPackages = [
        package
      ];

      environment.shellAliases = {
        ddg = "${getExe package} lite.duckduckgo.com";
        web = "${getExe package}";
      };
    };
in
{
  nixosModules.web = commonModule;
  darwinModules.web = commonModule;
}
