let
  commonModule =
    { lib, pkgs, ... }:
    let
      inherit (lib.meta) getExe;
    in
    {
      environment.shellAliases = {
        ddg = "${getExe pkgs.w3m} lite.duckduckgo.com";
        web = "${getExe pkgs.w3m}";
      };
    };
in
{
  nixosModules.web = commonModule;
  darwinModules.web = commonModule;
}
