{ inputs, ... }:
{
  flake.nixosModules.nixpkgs-read-only = inputs.nixpkgs + /nixos/modules/misc/nixpkgs/read-only.nix;
}
