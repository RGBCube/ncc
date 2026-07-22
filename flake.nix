{
  nixConfig = {
    extra-substituters = [
    ];

    extra-trusted-public-keys = [
    ];

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
    url = "github:RGBCube/nix-darwin";
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
    url = "github:feel-co/hjem";
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
    inputs.darwin.follows = "nix-darwin";
    inputs.home-manager.follows = "";
    inputs.systems.follows = "crash/systems";
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

  inputs.sudo-run0-shim = {
    url = "github:LordGrimmauld/run0-sudo-shim";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.nix-github-actions.follows = "";
    inputs.treefmt-nix.follows = "";
  };

  inputs.zmk-nix = {
    url = "github:lilyinstarlight/zmk-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs.lib.attrsets) filterAttrs mapAttrs' nameValuePair;
      inherit (inputs.nixpkgs.lib.filesystem) readDir;
      inherit (inputs.nixpkgs.lib.strings) hasSuffix removeSuffix;

      readCoal =
        directory:
        readDir directory
        |> filterAttrs (name: _: hasSuffix ".nix" name)
        |> mapAttrs' (name: _: nameValuePair (removeSuffix ".nix" name) "${directory}/${name}");
    in
    (import "${inputs.flake-parts}/lib.nix" {
      lib = import ./lib inputs.nixpkgs.lib;

      builtinModules = readCoal "${inputs.flake-parts}/modules";
      extraModules = readCoal "${inputs.flake-parts}/extras";
    }).mkFlake
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

          imports = filter (hasSuffix ".mod.nix") (listFilesRecursive ./.);
        }
      );
}
