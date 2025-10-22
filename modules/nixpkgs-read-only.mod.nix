let
  commonModule = inputs: inputs.os + /nixos/modules/misc/nixpkgs/read-only.nix;
in
{ inputs, ... }: {
  nixosModules.nixpkgs-read-only = commonModule inputs;
  darwinModules.nixpkgs-read-only = commonModule inputs;
}
