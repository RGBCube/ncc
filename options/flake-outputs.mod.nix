{
  config,
  inputs,
  lib,
  moduleLocation,
  ...
}:
let
  inherit (lib.attrsets) mapAttrs;
  inherit (lib.lists) singleton;
  inherit (lib.options) mkOption;
  inherit (lib.fixedPoints) fix;
  inherit (lib.modules) mkMerge;
  inherit (lib.types) deferredModule lazyAttrsOf;

  wrap =
    {
      kind,
      class ? null,
    }:
    name: value:
    fix (module: {
      _file = "${toString moduleLocation}#${kind}.${name}";
      key = module._file;

      ${if class == null then null else "_class"} = class;

      imports = singleton value;
    });
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
      <| wrap {
        kind = "nixosModules";
        class = "nixos";
      };
    description = "NixOS modules.";
  };

  options.flake.darwinModules = mkOption {
    type = lazyAttrsOf deferredModule;
    default = { };
    apply =
      mapAttrs
      <| wrap {
        kind = "darwinModules";
        class = "darwin";
      };
    description = "Darwin modules.";
  };

  options.flake.homeModules = mkOption {
    type = lazyAttrsOf deferredModule;
    default = { };
    apply =
      mapAttrs
      <| wrap {
        kind = "homeModules";
        class = "hjem";
      };
    description = "Home modules.";
  };

  options.flake.serviceModules = mkOption {
    type = lazyAttrsOf deferredModule;
    default = { };
    apply =
      mapAttrs
      <| wrap {
        kind = "serviceModules";
        class = "service";
      };
    description = "Modular service modules.";
  };

  # Very cool! -- Donald J. Trump
  options.commonModules = mkOption {
    type = lazyAttrsOf deferredModule;
    default = { };
    apply = mapAttrs <| wrap { kind = "commonModules"; };
    description = "Modules shared between NixOS and Darwin.";
  };

  config.flake.nixosModules = mkMerge [
    config.commonModules
    (config.flake.homeModules |> mapAttrs (_: module: { home.extraModules = singleton module; }))
  ];
  config.flake.darwinModules = mkMerge [
    config.commonModules
    (config.flake.homeModules |> mapAttrs (_: module: { home.extraModules = singleton module; }))
  ];
}
