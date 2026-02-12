let
  commonModule = {
    environment.defaultPackages = [ ];
  };
in
{
  flake.nixosModules.nuke-default-packages = commonModule;
  flake.darwinModules.nuke-default-packages = commonModule;
}
