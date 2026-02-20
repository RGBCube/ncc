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
      attrValues self.darwinModuless
      ++ singleton (
        { config, ... }:
        {
          nixpkgs.hostPlatform = "aarch64-darwin";

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

          # homeModules.home is already injected via home.extraModules.
          home.extraModules = attrValues <| removeAttrs self.homeModules [ "home" ];

          system.stateVersion = 5;
        }
      );
  };
}
