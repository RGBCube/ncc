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
  flake.nixosModules.secrets =
    { config, lib, ... }:
    let
      inherit (lib.lists) head singleton;
    in
    {
      imports = [
        inputs.agenix.nixosModules.age

        aliasModule
      ];

      age.identityPaths = [ "/media/key/.secrets.key" ];

      services.openssh.hostKeys = singleton {
        type = "ed25519";
        path = head config.age.identityPaths;
      };
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
