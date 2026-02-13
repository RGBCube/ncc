{
  flake.homeModules.secrets-manager =
    {
      osConfig,
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
      programs.nushell.aliases.age = # sh
        ''${getExe package} --identity ${head osConfig.age.identityPaths}'';

      packages = [
        package
      ];
    };
}
