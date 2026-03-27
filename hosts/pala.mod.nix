{
  self,
  inputs,
  lib,
  ...
}:
let
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) singleton;

in
{
  flake.darwinConfigurations.pala = inputs.nix-darwin.lib.darwinSystem {
    specialArgs = { inherit self inputs; };

    modules =
      attrValues self.commonModules
      ++ attrValues self.darwinModules
      ++ singleton {
        home.extraModules = attrValues self.homeModules;
      }
      ++ singleton (
        { config, ... }:
        {
          networking.hostName = "pala";
          networking.knownNetworkServices = [
            "Wi-Fi"
            "Thunderbolt Bridge"
          ];

          users.users.pala = {
            name = "pala";
            home = "/Users/pala";
          };
          home.users.pala = { };

          nixpkgs.hostPlatform = "aarch64-darwin";
          system.stateVersion = 5;
        }
      );
  };
}
