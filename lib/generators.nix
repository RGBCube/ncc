{ lib, ... }:
let
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.strings) concatLines;
  inherit (lib.lists) singleton flatten;
in
{
  # CLI flag config format used by bat.
  # true -> --flag, string/int -> --flag 'value'
  toCliFlagList =
    attrs:
    attrs
    |> mapAttrsToList (
      name: value: if value == true then "--${name}" else "--${name} '${toString value}'"
    )
    |> concatLines;

  # CLI flag config format used by ripgrep.
  # true -> --flag, string/int -> --flag<newline>value
  toCliArgumentList =
    attrs:
    attrs
    |> mapAttrsToList (
      name: value:
      if value == true then
        singleton "--${name}"
      else
        [
          "--${name}"
          (toString value)
        ]
    )
    |> flatten
    |> concatLines;
}
