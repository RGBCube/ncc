{ self, ... }:
{
  flake.homeModules.ripgrep =
    { lib, pkgs, ... }:
    let
      inherit (lib.meta) getExe;

      package = pkgs.ripgrep;
    in
    {
      programs.nushell.aliases.todo = # sh
        ''${getExe package} "todo|fixme" --colors match:fg:yellow --colors match:style:bold'';

      packages = [
        package
      ];

      xdg.config.files."ripgrep/ripgreprc".generator = self.lib.generators.toCliFlagList;
      xdg.config.files."ripgrep/ripgreprc".value = {
        line-number = true;
        smart-case = true;
      };
    };
}
