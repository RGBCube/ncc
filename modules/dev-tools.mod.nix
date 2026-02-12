{
  flake.homeModules.dev-tools =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.modules) mkIf;
      inherit (lib.strings) makeLibraryPath;
    in
    {
      environment.sessionVariables = {
        CARGO_NET_GIT_FETCH_WITH_CLI = "true";

        LIBRARY_PATH = mkIf config.nixpkgs.hostPlatform.isDarwin <| makeLibraryPath [ pkgs.libiconv ];
      };

      packages = [
        # C/C++
        pkgs.clang
        pkgs.clang-tools
        pkgs.lld

        # GO
        pkgs.go

        # RUST
        pkgs.cargo-deny
        pkgs.cargo-expand
        pkgs.cargo-fuzz
        pkgs.cargo-nextest

        pkgs.evcxr

        pkgs.taplo

        (pkgs.fenix.complete.withComponents [
          "cargo"
          "clippy"
          "rust-src"
          "rustc"
          "rustfmt"
        ])
      ];
    };
}
