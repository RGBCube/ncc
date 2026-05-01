{ self, ... }:
{
  flake.homeModules.inputs-gcroot =
    { lib, ... }:
    let
      inherit (lib.attrsets) attrValues;
      inherit (lib.lists) elem foldl' singleton;
      inherit (lib.trivial) flip;

      collect =
        collected: parent:
        (parent.inputs or { })
        |> attrValues
        |> flip foldl' collected (
          collected: child:
          if elem "${child}" collected then collected else collect (singleton "${child}" ++ collected) child
        );
    in
    {
      extraDependencies = collect [ ] self;
    };
}
