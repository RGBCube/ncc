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
  homeModules.claude-code =
    { pkgs, ... }:
    {
      packages = [
        pkgs.claude-code
      ];
    };

  nixosModules.claude-code = commonModule;
  darwinModules.claude-code = commonModule;
}
