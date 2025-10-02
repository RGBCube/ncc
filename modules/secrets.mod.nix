let
  commonModule =
    { lib, ... }:
    let
      inherit (lib.modules) mkAliasOptionModule;
    in
    mkAliasOptionModule [ "secrets" ] [ "age" "secrets" ];
in
{
  nixosModules.secrets =
    { inputs, ... }:
    {
      imports = [
        inputs.age.nixosModules.age

        commonModule
      ];

      age.identityPaths = [ "/etc/age/id" ];
    };

  darwinModules.secrets =
    { inputs, ... }:
    {
      imports = [
        inputs.age.darwinModules.age

        commonModule
      ];

      age.identityPaths = [ "/etc/age/id" ];
    };
}
