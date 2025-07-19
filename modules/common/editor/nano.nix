{ config, lib, ... }: let
  inherit (lib) disabled optionalAttrs;
in {
  programs = optionalAttrs config.isLinux {
    nano = disabled; # Garbage.
  };
}
