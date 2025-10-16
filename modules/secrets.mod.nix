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
{
  nixosModules.secrets =
    { inputs, ... }:
    {
      imports = [
        inputs.age.nixosModules.age

        commonModule
      ];
    };

  darwinModules.secrets =
    { inputs, ... }:
    {
      imports = [
        inputs.age.darwinModules.age

        commonModule
      ];
    };
}
