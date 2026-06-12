lib:
let
  inherit (lib.attrsets) recursiveUpdate;
  inherit (lib.filesystem) listFilesRecursive;
  inherit (lib.lists) filter foldl' map;
  inherit (lib.strings) hasSuffix;
in
lib.extend (
  final: prev:
  listFilesRecursive ./.
  |> filter (file: file != ./default.nix && hasSuffix ".nix" file)
  |> map (file: import file { self = final; })
  |> foldl' recursiveUpdate prev
)
