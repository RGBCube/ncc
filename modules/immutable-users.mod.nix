{
  flake.nixosModules.immutable-users = {
    users.mutableUsers = false;
  };
}
