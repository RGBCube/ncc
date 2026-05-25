{
  self,
  lib,
  flake-parts-lib,
  ...
}:
let
  inherit (lib.attrsets) recursiveUpdate;
  inherit (lib.options) mkOption;
  inherit (lib.types) anything lazyAttrsOf;
in
{
  options.flake = flake-parts-lib.mkSubmoduleOptions {
    lib' = mkOption {
      type = lazyAttrsOf anything;
      default = { };
    };
  };

  config.flake.lib = recursiveUpdate lib self.lib';
}
