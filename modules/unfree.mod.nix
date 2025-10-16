let
  commonModule =
    { config, lib, ... }:
    let
      inherit (lib.modules) mkOption;
      inherit (lib.types) listOf str;
      inherit (lib.lists) elem;
    in
    {
      options.nixpkgs.config.allowedUnfreePackageNames = mkOption {
        type = listOf str;
        default = [ ];
        description = "List of unfree package names to allow";
        example = [ "discord" "vscode" ];
      };

      config.nixpkgs.config.allowUnfreePredicate = package: 
        elem package.pname config.nixpkgs.config.allowedUnfreePackageNames;
    };
in
{
  nixosModules.unfree = commonModule;
  darwinModules.unfree = commonModule;
}