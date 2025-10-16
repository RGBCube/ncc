{
  homeModules.ripgrep =
    { lib, pkgs, ... }:
    let
      inherit (lib.meta) getExe;
      inherit (lib.strings) concatLines;

      package = pkgs.ripgrep;
    in
    {
      package = [
        package
      ];

      programs.nushell.aliases.todo = # sh
        ''${getExe package} "todo|fixme" --colors match:fg:yellow --colors match:style:bold'';

      xdg.config."ripgrep/ripgreprc".text = concatLines [
        "--line-number"
        "--smart-case"
      ];
    };
}
