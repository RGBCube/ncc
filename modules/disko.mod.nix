{ inputs, self, ... }:
{
  flake.nixosModules.hardware = self.nixosModules.disko;
  flake.nixosModules.disko = inputs.disko.nixosModules.disko;
}
