let
  commonModule =
    { config, lib, ... }:
    let
      inherit (lib.lists) elem;
      inherit (lib.options) mkOption;
      inherit (lib.types) listOf str;
    in
    {
      options.allowedUnfreePackageNames = mkOption {
        type = listOf str;
        default = [ ];
        description = "List of unfree package names to allow.";
        example = [
          "discord"
          "vscode"
        ];
      };

      config.nixpkgs.config.allowUnfreePredicate =
        package: elem package.pname config.allowedUnfreePackageNames;
    };
in
{
  flake.darwinModules.unfree = commonModule;
  flake.nixosModules.unfree = commonModule;
}
