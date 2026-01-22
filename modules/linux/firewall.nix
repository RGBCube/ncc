{ lib, ...}: let
  inherit (lib) enabled;
in {
  networking.nftables = enabled;
}
