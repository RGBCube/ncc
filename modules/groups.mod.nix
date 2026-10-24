{ self, ... }:
{
  flake.nixosModules.default.imports = [
    self.nixosModules.hardware
    self.nixosModules.kernel
    self.nixosModules.networking
    self.nixosModules.shell
  ];

  flake.darwinModules.default.imports = [
    self.darwinModules.desktop
    self.darwinModules.networking
    self.darwinModules.shell
  ];

  flake.homeModules.default.imports = [
    self.homeModules.cli
  ];
}
