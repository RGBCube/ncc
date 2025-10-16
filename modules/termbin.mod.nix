{
  homeModules.termbin =
    { lib, pkgs, ... }:
    let
      inherit (lib.attrsets) genAttrs;
      inherit (lib.meta) getExe;
      inherit (lib.trivial) const;
    in
    {
      programs.nushell.aliases =
        genAttrs [
          "termbin"
          "tb"
        ]
        <|
          const
            # sh
            ''${getExe pkgs.netcat} termbin.com 9999'';
    };
}
