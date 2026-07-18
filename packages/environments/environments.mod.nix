{
  perSystem =
    { lib, pkgs, ... }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.strings) makeLibraryPath optionalString;
    in
    {
      packages.c = pkgs.buildEnv {
        name = "c";
        paths = [
          pkgs.clang
          pkgs.clang-tools
          pkgs.lld
        ];
      };

      packages.fun = pkgs.buildEnv {
        name = "fun";
        paths = [
          pkgs.cowsay
          (pkgs.fortune.override { withOffensive = true; })
        ];
      };

      packages.go = pkgs.go;

      packages.kubernetes = pkgs.buildEnv {
        name = "kubernetes";
        paths = [
          pkgs.kubectl
          pkgs.kubernetes-helm
        ];
      };

      packages.python = pkgs.buildEnv {
        name = "python";
        paths = [
          pkgs.python3
          pkgs.uv
        ];

        nativeBuildInputs = singleton pkgs.makeWrapper;
        postBuild = ''
          wrapProgram $out/bin/uv \
            --set UV_PYTHON_PREFERENCE system \
            --set UV_PYTHON ${pkgs.python3}
        '';
      };

      packages.rust = pkgs.buildEnv {
        name = "rust";
        paths = [
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

        nativeBuildInputs = singleton pkgs.makeWrapper;
        postBuild = ''
          wrapProgram $out/bin/cargo \
            --set CARGO_NET_GIT_FETCH_WITH_CLI true \
            ${optionalString pkgs.stdenv.hostPlatform.isDarwin "--set LIBRARY_PATH ${
              makeLibraryPath <| singleton pkgs.libiconv
            }"}
        '';
      };
    };
}
