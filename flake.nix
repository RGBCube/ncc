{
  nixConfig = {
    experimental-features = [
      "cgroups"
      "flakes"
      "nix-command"
      "pipe-operators"
    ];

    builders-use-substitutes = true;
    flake-registry = "";
    http-connections = 50;
    show-trace = true;
    trusted-users = [
      "root"
      "@build"
      "@wheel"
      "@admin"
    ];
    use-cgroups = true;
    use-xdg-base-directories = true;
    warn-dirty = false;
  };

  inputs.nixpkgs = {
    url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  inputs.nix-darwin = {
    url = "github:nix-darwin/nix-darwin?ref=pull/1765/merge";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.nixos-facter = {
    url = "github:nix-community/nixos-facter-modules";
  };
  inputs.disko = {
    url = "github:RGBCube/disko/fix-bcachefs-unlock";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.hjem = {
    url = "github:feel-co/hjem?ref=pull/167/merge";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.flake-parts = {
    url = "github:hercules-ci/flake-parts";
    inputs.nixpkgs-lib.follows = "nixpkgs";
  };

  inputs.crate2nix = {
    url = "github:nix-community/crate2nix";
    inputs.cachix.follows = "";
    inputs.flake-compat.follows = "";
    inputs.flake-parts.follows = "flake-parts";
    inputs.nix-test-runner.follows = "";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.fenix = {
    url = "github:nix-community/fenix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.advisory-db = {
    url = "github:rustsec/advisory-db";
    flake = false;
  };

  inputs.agenix = {
    url = "github:ryantm/agenix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.homebrew = {
    url = "github:zhaofengli/nix-homebrew";
  };
  inputs.homebrew-core = {
    url = "github:homebrew/homebrew-core";
    flake = false;
  };
  inputs.homebrew-cask = {
    url = "github:homebrew/homebrew-cask";
    flake = false;
  };

  inputs.crash = {
    url = "github:RGBCube/crash";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.themes = {
    url = "github:RGBCube/ThemeNix";
  };

  inputs.helium = {
    url = "github:amaanq/helium-flake";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.ublock = {
    url = "github:imputnet/uBlock";
    flake = false;
  };

  inputs.zmk-nix = {
    url = "github:lilyinstarlight/zmk-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    toplevelInputs:
    # OVERRIDE INPUTS
    let
      inputs =
        let
          inherit (toplevelInputs.nixpkgs.lib.filesystem) listFilesRecursive;
          inherit (toplevelInputs.nixpkgs.lib.lists) filter foldl';
          inherit (toplevelInputs.nixpkgs.lib.trivial) importJSON const id;
          inherit (toplevelInputs.nixpkgs.lib.strings)
            unsafeDiscardStringContext
            hasSuffix
            removePrefix
            removeSuffix
            ;
          inherit (toplevelInputs.nixpkgs.lib.attrsets) getAttrs attrNames unionOfDisjoint;
          inherit (toplevelInputs.nixpkgs.lib.flakes) flakeRefToString;
          inherit (builtins) getFlake;
        in
        listFilesRecursive ./.
        |> map toString

        |> filter (hasSuffix "/flake.nix")
        |> map (removeSuffix "/flake.nix")

        |> map (
          workspace:
          let
            lock = importJSON "${workspace}/flake.lock";
            value =
              {
                type = "path";
                # XXX: Consider using flake-compat to fetch the flake instead of getFlake to avoid
                # infinite recursion when importing an external flake-parts module that modifies
                # the toplevel.
                inherit (toplevelInputs.self) narHash;

                path = "${toplevelInputs.self}";
                dir =
                  removePrefix "${toplevelInputs.self}" workspace

                  # WORKAROUND: Nix crashes when ?dir on a flakeref has any "/".
                  #
                  # So we have to strip the initial / and nested paths don't work (as we _have to_ have a / there)
                  |> removePrefix "/"; # REMOVE: when `nix --version` > 2.35.3
              }
              |> flakeRefToString
              |> unsafeDiscardStringContext
              |> getFlake;
          in
          value.inputs
          # Avoids infinite recursion, as our output depends on `inputs`
          |> (if workspace == toString ./. then const toplevelInputs else id)
          # Needed because otherwise the whole attrset will depend on all the flakes being
          # `getFlake`'d, causing Nix to fetch all inputs. This defers that to each value force.
          |> getAttrs (attrNames lock.nodes.${lock.root}.inputs or { })
        )

        |> foldl' unionOfDisjoint {
          inherit (toplevelInputs) self;
        };
    in
    # OVERRIDE LIB
    ((import "${inputs.flake-parts}/flake.nix").outputs (
      inputs.flake-parts.inputs
      // {
        self = inputs.flake-parts;

        nixpkgs-lib = inputs.flake-parts.inputs.nixpkgs-lib // {
          lib = import ./lib inputs.nixpkgs.lib;
        };
      }
    )).lib.mkFlake
      { inherit inputs; }
      (
        { lib, ... }:
        let
          inherit (lib.filesystem) listFilesRecursive;
          inherit (lib.lists) filter;
          inherit (lib.strings) hasSuffix;
        in
        {
          systems = [
            "aarch64-darwin"
            "aarch64-linux"
            "x86_64-linux"
          ];

          imports = listFilesRecursive ./. |> filter (hasSuffix ".mod.nix");
        }
      );
}
