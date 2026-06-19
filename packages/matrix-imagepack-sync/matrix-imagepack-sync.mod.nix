{ inputs, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      tools = import "${inputs.crate2nix}/tools.nix" { inherit pkgs; };

      generated = tools.generatedCargoNix {
        name = (lib.importTOML ./Cargo.toml).package.name;
        src = ./.;
      };

      cargoNix = pkgs.callPackage "${generated}/default.nix" {
        buildRustCrateForPkgs =
          p:
          p.buildRustCrate.override {
            # Per-crate build fixups. aws-lc-sys (matrix-sdk's rustls TLS
            # backend) is already covered by nixpkgs' defaultCrateOverrides,
            # which forces its cmake backend — the cc backend miscompiles on
            # Darwin (the dsymutil failure under the bare toolchain).
            defaultCrateOverrides = p.defaultCrateOverrides // {
            };
          };
      };
    in
    {
      packages.matrix-imagepack-sync = cargoNix.rootCrate.build;
    };
}
