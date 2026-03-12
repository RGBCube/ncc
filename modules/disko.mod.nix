{ inputs, ... }:
{
  flake.nixosModules.disko = inputs.disko.nixosModules.disko;
}
