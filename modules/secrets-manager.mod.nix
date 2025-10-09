let
  commonModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) head;
      inherit (lib.meta) getExe;

      package = pkgs.ragenix;
    in
    {
      environment.systemPackages = [
        package
      ];

      environment.shellAliases.ragenix = "${getExe package} --identity ${head config.age.identityPaths}";
    };
in
{
  nixosModules.secrets-manager = commonModule;
  darwinModules.secrets-manager = commonModule;
}
