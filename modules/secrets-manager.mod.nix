{
  homeModules.secrets-manager =
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
      programs.nushell.aliases = # sh
        ''${getExe package} --identity ${head config.age.identityPaths}'';

      packages = [
        package
      ];
    };
}
