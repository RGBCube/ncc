{ lib, ... }:
let
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.strings) concatLines;
in
{
  # CLI flag config format used by bat, ripgrep, etc.
  # true -> --flag, string/int -> --flag=value
  flake.lib.generators.toCliFlagList =
    attrs:
    concatLines
    <| mapAttrsToList (
      name: value: if value == true then "--${name}" else "--${name}=${toString value}"
    ) attrs;
}
