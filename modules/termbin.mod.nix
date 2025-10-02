let
  commonModule =
    { lib, pkgs, ... }:
    let
      inherit (lib.attrsets) genAttrs;
      inherit (lib.meta) getExe;
      inherit (lib.trivial) const;
    in
    {
      environment.shellAliases =
        genAttrs [
          "termbin"
          "tb"
        ]
        <| const "${getExe pkgs.netcat} termbin.com 9999";
    };
in
{
  nixosModules.termbin = commonModule;
  darwinModules.termbin = commonModule;
}
