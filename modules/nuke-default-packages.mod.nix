{
  flake.commonModules.nuke-default-packages = {
    environment.defaultPackages = [ ];
  };

  flake.nixosModules.nuke-default-packages = {
    environment.stub-ld.enable = false;
  };
}
