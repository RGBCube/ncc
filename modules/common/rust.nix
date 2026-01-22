{ config, lib, pkgs, ... }: let
  inherit (lib) makeLibraryPath mkIf;
in {
  environment.variables = {
    CARGO_NET_GIT_FETCH_WITH_CLI = mkIf config.isDesktop "true";

    LIBRARY_PATH = mkIf config.isDarwin <| makeLibraryPath [
      pkgs.libiconv
    ];
  };

  environment.systemPackages = mkIf config.isDesktop [
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
}
