{ self, ... }:
{
  flake.homeModules.packages-kubernetes =
    { pkgs, ... }:
    {
      packages = [
        pkgs.kubectl
        pkgs.kubernetes-helm
      ];
    };

  flake.homeModules.packages-media =
    { pkgs, ... }:
    {
      packages = [
        pkgs.yt-dlp
      ];
    };

  flake.homeModules.packages-shell-utils =
    { pkgs, ... }:
    {
      packages = [
        pkgs.asciinema
        pkgs.fastfetch
        pkgs.fd
        pkgs.openssl
        pkgs.p7zip
        pkgs.rclone
        pkgs.tokei
        pkgs.uutils-coreutils-noprefix
        pkgs.yazi
      ];
    };

  flake.homeModules.packages-wisdom =
    { pkgs, ... }:
    {
      packages = [
        pkgs.cowsay
        (pkgs.fortune.override { withOffensive = true; })
      ];
    };

  flake.homeModules.packages-dev-tools-cc =
    { pkgs, ... }:
    {
      packages = [
        pkgs.clang
        pkgs.clang-tools
        pkgs.lld
      ];
    };

  flake.homeModules.packages-dev-tools-go =
    { pkgs, ... }:
    {
      packages = [
        pkgs.go
      ];
    };

  flake.homeModules.packages-dev-tools-rust =
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

        LIBRARY_PATH = mkIf osConfig.nixpkgs.hostPlatform.isDarwin <| makeLibraryPath [ pkgs.libiconv ];
      };

      packages = [
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

  flake.homeModules.packages-dev-tools-python =
    { pkgs, ... }:
    let
      package = pkgs.python3;
    in
    {
      environment.sessionVariables = {
        UV_PYTHON_PREFERENCE = "system";
        UV_PYTHON = "${package}";
      };

      packages = [
        package
        pkgs.uv
      ];
    };

  flake.nixosModules.packages-debugging-gui =
    { lib, pkgs, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      allowedUnfreePackageNames = singleton "ida-pro";

      environment.systemPackages = singleton self.packages.x86_64-linux.ida-pro;
    };

  flake.nixosModules.packages-debugging =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.strace
        pkgs.usbutils
      ];
    };

  flake.homeModules.packages-debugging =
    { pkgs, ... }:
    {
      packages = [
        pkgs.hyperfine
        pkgs.typos
      ];
    };
}
