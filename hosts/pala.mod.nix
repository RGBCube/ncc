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
      {
        imports = [
          self.darwinModules.communication
          self.darwinModules.media
          {
            home.extraModules = singleton self.homeModules.ai;
          }
        ];

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
