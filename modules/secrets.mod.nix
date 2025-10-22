let
  commonModule =
    { lib, ... }:
    let
      inherit (lib.modules) mkAliasOptionModule;
    in
    {
      imports = [ (mkAliasOptionModule [ "secrets" ] [ "age" "secrets" ]) ];

      age.identityPaths = [ "/etc/age/id" ];
    };
in
{ inputs, ... }:
{
  nixosModules.secrets = {
    imports = [
      inputs.age.nixosModules.age

      commonModule
    ];
  };

  darwinModules.secrets = {
    imports = [
      inputs.age.darwinModules.age

      commonModule
    ];
  };
}
