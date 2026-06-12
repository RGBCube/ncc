{ self }:
let
  inherit (self.attrsets) mapAttrsToList;
  inherit (self.strings) concatLines;
  inherit (self.lists) singleton flatten;
in
{
  # CLI flag config format used by bat.
  # true -> --flag, string/int -> --flag 'value'
  generators.toCliFlagList =
    attrs:
    attrs
    |> mapAttrsToList (
      name: value: if value == true then "--${name}" else "--${name} '${toString value}'"
    )
    |> concatLines;

  # CLI flag config format used by ripgrep.
  # true -> --flag, string/int -> --flag<newline>value
  generators.toCliArgumentList =
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
