{
  self,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
in
{
  flake.machines.pala = {
    ssh.key = self.people.self.ssh.key;
  };

  imports =
    singleton
    <| lib.systems.darwinSystem "pala" {
      imports = [
        self.darwinModules.ai
        self.darwinModules.communication
        self.darwinModules.media
        self.darwinModules.version-control
      ];

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
