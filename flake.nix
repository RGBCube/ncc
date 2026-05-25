{
  nixConfig = {
    extra-substituters = [
      "https://cache.garnix.io/"
      "https://nix-community.cachix.org/"
    ];

    extra-trusted-public-keys = [
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
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
    inputs.nix-darwin.follows = "nix-darwin";
  };
  inputs.hjem-rum = {
    url = "github:snugnug/hjem-rum";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.hjem.follows = "hjem";
    inputs.ndg.follows = "";
    inputs.treefmt-nix.follows = "";
  };

  inputs.flake-parts = {
    url = "github:hercules-ci/flake-parts";
    inputs.nixpkgs-lib.follows = "nixpkgs";
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
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
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
