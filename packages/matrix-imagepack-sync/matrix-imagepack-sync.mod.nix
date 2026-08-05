{ lib, ... }:
let
  inherit (lib.lists) singleton;
in
{
  imports = singleton <| lib.rust.package { source = ./.; };
}
