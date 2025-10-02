let
  commonModule = { inputs, ... }: inputs.os + /nixos/modules/misc/nixpkgs/read-only.nix;
in
{
  nixosModules.read-only = commonModule;
  darwinModules.read-only = commonModule;
}
