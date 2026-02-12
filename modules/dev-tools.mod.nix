{
  flake.homeModules.dev-tools =
    {
      lib,
      osConfig,
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
        RUSTC_BOOTSTRAP = "1";

        LIBRARY_PATH = mkIf osConfig.nixpkgs.hostPlatform.isDarwin <| makeLibraryPath [ pkgs.libiconv ];
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

        pkgs.cargo
        pkgs.clippy
        pkgs.rust-analyzer
        pkgs.rustc
        pkgs.rustfmt
      ];
    };
}
