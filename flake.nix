{
  inputs.os = {
    url = "github:NixOS/nixpkgs/nixos-unstable-small";
  };
  inputs.os-linux = {
    url = "github:nix-community/nixos-facter-modules";
  };
  inputs.os-darwin = {
    url = "github:LnL7/nix-darwin";
    inputs.nixpkgs.follows = "os";
  };

  inputs.home = {
    url = "github:SquirrelModeller/hjem";
    inputs.nixpkgs.follows = "os";
    inputs.darwin.follows = "os-darwin";
    inputs.smfh.follows = "";
    inputs.ndg.follows = "";
  };
  inputs.home-modules = {
    url = "github:snugnug/hjem-rum";
    inputs.nixpkgs.follows = "os";
    inputs.hjem.follows = "home";
    inputs.ndg.follows = "";
    inputs.treefmt-nix.follows = "";
  };

  inputs.parts = {
    url = "github:hercules-ci/flake-parts";
    inputs.nixpkgs-lib.follows = "os";
  };

  inputs.age = {
    url = "github:ryantm/agenix";
    inputs.nixpkgs.follows = "os";
    inputs.darwin.follows = "os-darwin";
    inputs.home-manager.follows = ""; # Not using home-manager, so don't fetch it.
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

  inputs.sudo-run0-shim = {
    url = "github:LordGrimmauld/run0-sudo-shim";
    inputs.nixpkgs.follows = "os";
    inputs.nix-github-actions.follows = "";
    inputs.treefmt-nix.follows = "";
  };

  outputs =
    inputs:
    inputs.parts.lib.mkFlake { inherit inputs; } (
      { lib, ... }:
      let
        inherit (lib.filesystem) listFilesRecursive;
        inherit (lib.lists) filter;
        inherit (lib.strings) hasSuffix;
      in
      {
        imports = filter (hasSuffix ".mod.nix") (listFilesRecursive ./.);
      }
    );
}
