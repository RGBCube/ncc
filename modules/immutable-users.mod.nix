{ self, ... }:
{
  flake.nixosModules.default = self.nixosModules.immutable-users;
  flake.nixosModules.immutable-users = {
    users.mutableUsers = false;

    environment.etc."shells".enable = false;
  };
}
