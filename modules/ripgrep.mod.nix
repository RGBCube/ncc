let
  commonModule =
    { lib, pkgs, ... }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.strings) concatLines;
    in
    {
      environment.systemPackages = [
        pkgs.ripgrep
      ];

      environment.shellAliases.todo = # sh
        ''rg "todo|fixme" --colors match:fg:yellow --colors match:style:bold'';

      home.sharedModules = singleton {
        xdg.config."ripgrep/ripgreprc".text = concatLines [
          "--line-number"
          "--smart-case"
        ];
      };
    };
in
{
  nixosModules.ripgrep = commonModule;
  darwinModules.ripgrep = commonModule;
}
