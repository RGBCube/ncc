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
          self.darwinModules.ai
          self.darwinModules.communication
          self.darwinModules.media
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
