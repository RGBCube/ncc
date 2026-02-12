{ inputs, ... }:
{
  flake.nixosModules.hardware-report =
    { lib, ... }:
    let
      inherit (lib.modules) mkAliasOptionModule;
    in
    {
      imports = [
        inputs.nixos-facter.nixosModules.facter

        (mkAliasOptionModule [ "hardware" "report" ] [ "facter" "reportPath" ])
      ];
    };
}
