{ self, lib, ... }:
let
  inherit (lib.attrsets) recursiveUpdate;
in
{
  flake.lib = recursiveUpdate lib self.lib';
}
