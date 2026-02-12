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
  flake.nixosModules.secrets = {
    imports = [
      inputs.age.nixosModules.age

      commonModule
    ];
  };

  flake.darwinModules.secrets = {
    imports = [
      inputs.age.darwinModules.age

      commonModule
    ];
  };
}
