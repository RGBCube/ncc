{ self, ... }:
let
  commonModule = {
    nixpkgs.config.allowedUnfreePackageNames = [ "claude-code" ];

    home.extraModules = [ self.homeModules.claude-code ];
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
