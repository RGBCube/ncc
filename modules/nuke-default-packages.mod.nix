let
  commonModule = {
    environment.defaultPackages = [ ];
  };
in
{
  flake.nixosModules.nuke-default-packages =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      imports = singleton commonModule;

      environment.stub-ld.enable = false;
    };

  flake.darwinModules.nuke-default-packages = commonModule;
}
