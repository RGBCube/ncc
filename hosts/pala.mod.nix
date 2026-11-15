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
    <| lib.systems.darwinSystem [ "software" "hate" "host" "pala" ] {
      imports = [
        self.darwinModules.ai
        self.darwinModules.communication
        self.darwinModules.media
        self.darwinModules.version-control
      ];

      machine.ssh = {
        key = self.people.self.ssh.key;
      };

      networking.knownNetworkServices = [
        "Wi-Fi"
        "Thunderbolt Bridge"
      ];

      system.primaryUser = "pala";
      users.users.pala = {
        name = "pala";
        home = "/Users/pala";
      };
      home.users.pala = { };

      nixpkgs.hostPlatform = "aarch64-darwin";
      system.stateVersion = 5;
    };
}
