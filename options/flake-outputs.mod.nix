{
  config,
  inputs,
  lib,
  moduleLocation,
  ...
}:
let
  inherit (lib.attrsets) mapAttrs optionalAttrs;
  inherit (lib.lists) singleton;
  inherit (lib.options) mkOption;
  inherit (lib.fixedPoints) fix;
  inherit (lib.types) deferredModule lazyAttrsOf;

  wrap =
    kind: name: value:
    fix (module: {
      _file = "${toString moduleLocation}#${kind}.${name}";
      key = module._file;
      imports = singleton value;
    });

  wrapSystem =
    { key, class }:
    name: value:
    wrap key name value
    // {
      _class = class;
    }
    // optionalAttrs (config.flake.homeModules ? ${name}) {
      home.extraModules = singleton config.flake.homeModules.${name};
    };
in
{
  # flake-parts doesn't declare `key`, so deduplication doesn't happen.
  #
  # We re-declare it ourselves with `key`.
  disabledModules = singleton "${inputs.flake-parts}/modules/nixosModules.nix";

  options.flake.nixosModules = mkOption {
    type = lazyAttrsOf deferredModule;
    default = { };
    apply =
      mapAttrs
      <| wrapSystem {
        key = "nixosModules";
        class = "nixos";
      };
    description = "NixOS modules.";
  };

  options.flake.darwinModules = mkOption {
    type = lazyAttrsOf deferredModule;
    default = { };
    apply =
      mapAttrs
      <| wrapSystem {
        key = "darwinModules";
        class = "darwin";
      };
    description = "Darwin modules.";
  };

  options.flake.homeModules = mkOption {
    type = lazyAttrsOf deferredModule;
    default = { };
    apply = mapAttrs (name: value: wrap "homeModules" name value // { _class = "hjem"; });
    description = "Home modules.";
  };

  options.flake.modularServices = mkOption {
    type = lazyAttrsOf deferredModule;
    default = { };
    apply = mapAttrs (name: value: wrap "modularServices" name value // { _class = "service"; });
    description = "Modular service modules.";
  };

  # Very cool! -- Donald J. Trump
  options.commonModules = mkOption {
    type = lazyAttrsOf deferredModule;
    default = { };
    apply = mapAttrs <| wrap "commonModules";
    description = "Modules shared between NixOS and Darwin.";
  };

  config.flake.nixosModules = config.commonModules;
  config.flake.darwinModules = config.commonModules;
}
