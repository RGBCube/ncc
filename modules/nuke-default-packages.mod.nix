let
  commonModule = {
    environment.defaultPackages = [ ];
  };
in
{
  nixosModules.nuke-default-packages = commonModule;
  darwinModules.nuke-default-packages = commonModule;
}
