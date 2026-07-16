{ self, ... }:
{
  flake.nixosModules.default.imports = [
    self.nixosModules.boot
    self.nixosModules.hardware
    self.nixosModules.networking
    self.nixosModules.shell
    self.nixosModules.version-control
  ];

  flake.darwinModules.default.imports = [
    self.darwinModules.desktop
    self.darwinModules.networking
    self.darwinModules.shell
    self.darwinModules.version-control
  ];

  flake.homeModules.default.imports = [
    self.homeModules.cli
  ];
}
