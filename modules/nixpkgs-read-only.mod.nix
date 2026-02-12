let
  commonModule = inputs: inputs.os + /nixos/modules/misc/nixpkgs/read-only.nix;
in
{ inputs, ... }: {
  flake.nixosModules.nixpkgs-read-only = commonModule inputs;
  flake.darwinModules.nixpkgs-read-only = commonModule inputs;
}
