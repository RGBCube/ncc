let
  commonModule = {
    environment.defaultPackages = [ ];
  };
in
{
  nixosModules.default-packages = commonModule;
  darwinModules.default-packages = commonModule;
}
