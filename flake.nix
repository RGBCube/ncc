{
  description = "RGBCube's Config Collection";

  nixConfig = {
    extra-substituters = [
      "https://cache.rgbcu.be/"
      "https://cache.garnix.io/"
      "https://cache.privatevoid.net"
      "https://hyprland.cachix.org/"
      "https://nix-community.cachix.org/"
    ];

    extra-trusted-public-keys = [
      "cache.rgbcu.be:nBN/5Qg5E8GIYwaoslm9DYo2zeqlBiCVNCPf17djr+w="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "cache.privatevoid.net:SErQ8bvNWANeAvtsOESUwVYr2VJynfuc9JRwlzTTkVg="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];

    experimental-features = [
      "cgroups"
      "flakes"
      "nix-command"
      "pipe-operators"
    ];

    builders-use-substitutes = true;
    flake-registry           = "";
    http-connections         = 50;
    lazy-trees               = true;
    show-trace               = true;
    trusted-users            = [ "root" "@build" "@wheel" "@admin" ];
    use-cgroups              = true;
    warn-dirty               = false;
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nix-darwin = {
      url = "github:LnL7/nix-darwin";

      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    homebrew-core    = {
      url = "github:homebrew/homebrew-core";

      flake = false;
    };
    homebrew-cask    = {
      url = "github:homebrew/homebrew-cask";

      flake = false;
    };

    home-manager = {
      url = "github:nix-community/home-manager";

      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";

      inputs.nixpkgs.follows      = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    agenix = {
      url = "github:ryantm/agenix";

      inputs.nixpkgs.follows      = "nixpkgs";
      inputs.darwin.follows       = "nix-darwin";
      inputs.home-manager.follows = "home-manager";
    };

    nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver/master";

      inputs.nixpkgs.follows = "nixpkgs";
    };

    fenix = {
      url = "github:nix-community/fenix";

      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix.url = "github:DeterminateSystems/nix-src";

    github2forgejo = {
      url = "github:RGBCube/GitHub2Forgejo";

      inputs.nixpkgs.follows = "nixpkgs";
    };

    crash = {
      url = "github:RGBCube/crash";

      inputs.nixpkgs.follows = "nixpkgs";
    };

    themes.url = "github:RGBCube/ThemeNix";
  };

  outputs = inputs @ { nixpkgs, nix-darwin, ... }: let
    inherit (builtins) readDir;
    inherit (nixpkgs.lib) attrsToList const groupBy listToAttrs mapAttrs nameValuePair;

    lib' = nixpkgs.lib.extend (const <| const <| nix-darwin.lib);
    lib  = lib'.extend <| import ./lib inputs;

    hostsByType = readDir ./hosts
      |> mapAttrs (name: const <| import ./hosts/${name} lib)
      |> attrsToList
      |> groupBy ({ value, ... }:
        if value ? class && value.class == "nixos" then
          "nixosConfigurations"
        else
          "darwinConfigurations")
      |> mapAttrs (const listToAttrs);

    hostConfigs = hostsByType.darwinConfigurations // hostsByType.nixosConfigurations
      |> attrsToList
      |> map ({ name, value }: nameValuePair name value.config)
      |> listToAttrs;
  in hostsByType // hostConfigs // {
    inherit inputs lib;

    herculesCI = { ... }: {
      ciSystems = [ "aarch64-linux" "x86_64-linux" ];
    };
  };
}
