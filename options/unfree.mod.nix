{
  flake.commonModules.unfree =
    { config, lib, ... }:
    let
      inherit (lib.lists) elem;
      inherit (lib.options) mkOption;
      inherit (lib.strings) getName;
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
        package: elem (getName package) config.allowedUnfreePackageNames;
    };
}
