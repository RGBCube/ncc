let
  commonModule = { inputs, ... }: inputs.os + /nixos/modules/misc/nixpkgs/read-only.nix;
in
{
  nixosModules.nixpkgs-read-only = commonModule;
  darwinModules.nixpkgs-read-only = commonModule;
}
