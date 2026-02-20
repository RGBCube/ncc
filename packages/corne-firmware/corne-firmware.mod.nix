{ inputs, lib, ... }:
let
  inherit (lib.attrsets) hasAttr optionalAttrs;
in
{
  perSystem =
    {
      self',
      system,
      ...
    }:
    optionalAttrs (hasAttr system inputs.zmk-nix.packages) {
      packages.corne-firmware = inputs.zmk-nix.legacyPackages.${system}.buildSplitKeyboard {
        name = "corne-firmware";

        src = ./.;

        board = "nice_nano@2.0.0";
        shield = "corne_%PART% nice_view_adapter nice_view";

        zephyrDepsHash = "sha256-+FTVUUnfgHMRLM17GghIdUIEgoAmlQNXm13jPXLR03k=";

        meta = {
          description = "ZMK firmware";
          license = lib.licenses.mit;
          platforms = lib.platforms.all;
        };
      };

      packages.corne-flash = inputs.zmk-nix.packages.${system}.flash.override {
        inherit (self'.packages) firmware;
      };

      packages.corne-update = inputs.zmk-nix.packages.${system}.update;

      devShells.corne = inputs.zmk-nix.devShells.${system}.default;
    };
}
