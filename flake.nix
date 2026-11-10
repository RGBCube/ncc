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

  # Not inlined on purpose because of pipe-operators. Currently, Nix
  # will prompt you to accept the pipe-operators experimental-feature,
  # but if we inline it, Nix can't even parse flake.nix so it can't prompt you.
  outputs = inputs: import ./flake.output.nix inputs;
}
