{
  flake.darwinModules.primary-user =
    { config, lib, ... }:
    let
      inherit (lib.attrsets) attrNames filterAttrs;
      inherit (lib.lists) head;
      inherit (lib.strings) hasPrefix;
    in
    {
      system.primaryUser =
        config.users.users
        |> filterAttrs (_: { home, ... }: home != null && hasPrefix "/Users/" home)
        |> attrNames
        |> head;
    };
}
