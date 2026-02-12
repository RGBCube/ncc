{ self, ... }:
let
  commonModule =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      nixpkgs.config.allowedUnfreePackageNames = [ "claude-code" ];

      home.extraModules = singleton self.homeModules.claude-code;
    };
in
{
  flake.homeModules.claude-code =
    { pkgs, ... }:
    {
      packages = [
        pkgs.claude-code
      ];
    };

  flake.nixosModules.claude-code = commonModule;
  flake.darwinModules.claude-code = commonModule;
}
