{
  nixosModules.hardware-report =
    { inputs, lib, ... }:
    let
      inherit (lib.modules) mkAliasOptionModule;
    in
    {
      imports = [
        inputs.os-linux.nixosModules.facter

        (mkAliasOptionModule [ "hardware" "report" ] [ "facter" "reportPath" ])
      ];
    };
}
