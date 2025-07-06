{ config, lib, ... }: let
  inherit (lib) mkValue;
in {
  options.unfree.allowedNames = mkValue [];

  config.nixpkgs.config.allowUnfreePredicate = package: lib.elem package.pname config.unfree.allowedNames;
}
