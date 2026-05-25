{
  lib,
  moduleLocation,
  ...
}:
let
  inherit (lib.attrsets) mapAttrs optionalAttrs;
  inherit (lib.lists) singleton;
  inherit (lib.options) mkOption;
  inherit (lib.types) deferredModule lazyAttrsOf;

  wrap =
    kind: name: value:
    {
      _file = "${toString moduleLocation}#${kind}.${name}";
      imports = singleton value;
    }
    # Preserve meta.
    // optionalAttrs (value ? meta) {
      inherit (value) meta;
    };
in
{
  options.flake.commonModules = mkOption {
    type = lazyAttrsOf deferredModule;
    default = { };
    apply = mapAttrs (wrap "commonModules");
    description = "Modules shared between NixOS and Darwin.";
  };

  options.flake.darwinModules = mkOption {
    type = lazyAttrsOf deferredModule;
    default = { };
    apply = mapAttrs (wrap "darwinModules");
    description = "Darwin modules.";
  };

  options.flake.homeModules = mkOption {
    type = lazyAttrsOf deferredModule;
    default = { };
    apply = mapAttrs (wrap "homeModules");
    description = "Home modules.";
  };

  options.flake.modularServices = mkOption {
    type = lazyAttrsOf deferredModule;
    default = { };
    apply = mapAttrs (wrap "modularServices");
    description = "Modular service modules.";
  };
}
