{ self }:
{
  systems.darwinSystem =
    hostName: module:
    { inputs, ... }:
    {
      flake.darwinConfigurations.${hostName} = inputs.nix-darwin.lib.darwinSystem {
        lib = self;

        modules = [
          module

          {
            networking.hostName = hostName;
          }
        ];
      };
    };

  systems.nixosSystem =
    hostName: module:
    { inputs, ... }:
    {
      flake.nixosConfigurations.${hostName} = self.nixosSystem {
        modules = [
          module

          {
            networking.hostName = hostName;
          }
        ];
      };

      perSystem =
        { pkgs, ... }:
        {
          packages."installer-${hostName}" = pkgs.callPackage (
            {
              lib,
              nixos-install,
              writers,
            }:
            let
              inherit (lib.meta) getExe getExe';
            in
            writers.writeNuBin "install-${hostName}" /* nu */ ''
              def main [] {
                let mountpoint = "/mnt"

                mkdir $mountpoint
                # bcachefs format refuses unless the mount-point parent is 0755.
                ^${getExe' pkgs.uutils-coreutils-noprefix "chmod"} 755 $mountpoint

                DISKO_SKIP_SWAP=1 ^${inputs.self.nixosConfigurations.${hostName}.config.system.build.diskoScript}

                # TODO: Make this a store path?
                (^nix copy
                  --no-check-sigs
                  --to $"local?root=($mountpoint)"
                  ${inputs.self.nixosConfigurations.${hostName}.config.system.build.toplevel})

                (exec ${getExe nixos-install}
                  --no-channel-copy
                  --no-root-password
                  --system ${inputs.self.nixosConfigurations.${hostName}.config.system.build.toplevel}
                  --root $mountpoint)
              }
            ''
          ) { };
        };
    };
}
