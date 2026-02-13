{
  self,
  inputs,
  lib,
  ...
}:
let
  inherit (lib.attrsets) attrValues;
in
{
  flake.darwinConfigurations.pala = inputs.nix-darwin.lib.darwinSystem {
    specialArgs = { inherit self inputs; };

    modules = (attrValues (removeAttrs self.darwinModules [ "hickory-dns" ])) ++ [
      (
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
          home.users.pala = {};

          # homeModules.home is already injected via home.extraModules.
          home.extraModules = attrValues <| removeAttrs self.homeModules [ "home" ];

          secrets.id.file = ./id.age;
          secrets.id-cull.file = ./id-cull.age;
          secrets.id-no.file = ./id-no.age;

          services.openssh.extraConfig = /* sshclientconfig */ ''
            HostKey ${config.secrets.id.path}
            HostKey ${config.secrets.id-cull.path}
            HostKey ${config.secrets.id-no.path}
          '';

          system.stateVersion = 5;
        }
      )
    ];
  };
}
