let
  aliasModule =
    { lib, ... }:
    let
      inherit (lib.modules) mkAliasOptionModule;
    in
    {
      imports = [ (mkAliasOptionModule [ "secrets" ] [ "age" "secrets" ]) ];
    };
in
{ inputs, ... }:
{
  flake.nixosModules.secrets = {
    imports = [
      inputs.agenix.nixosModules.age

      aliasModule
    ];

    age.identityPaths = [ "/etc/age/id" ];
  };

  flake.darwinModules.secrets =
    { config, ... }:
    {
      imports = [
        inputs.agenix.darwinModules.age

        aliasModule
      ];

      age.identityPaths = [ "/Users/${config.system.primaryUser}/.ssh/id" ]; # FIXME: This path shouldn't exist, but does because of agenix (sigh)
    };

  flake.homeModules.secrets-manager =
    {
      pkgs,
      ...
    }:
    {
      packages = [
        pkgs.ragenix
      ];
    };
}
