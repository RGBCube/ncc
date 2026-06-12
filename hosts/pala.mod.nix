{
  self,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
in
{
  imports =
    singleton
    <| lib.systems.darwinSystem "pala" (
      { lib, ... }:
      let
        inherit (lib.attrsets) attrValues removeAttrs;
        inherit (lib.lists) singleton;
      in
      {
        imports =
          attrValues (removeAttrs self.commonModules [ "authoritative" ])
          ++ attrValues self.darwinModules
          ++ singleton {
            home.extraModules = attrValues self.homeModules;
          };

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
}
