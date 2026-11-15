{ self }:
let
  inherit (self.attrsets) setAttrByPath;
  inherit (self.lists)
    init
    last
    optionals
    singleton
    ;
  inherit (self.meta) getExe';
  inherit (self.trivial) importJSON;
  inherit (self.types.dns) name;

  sshfp =
    { config, pkgs, ... }:
    importJSON
    <| pkgs.stdenvNoCC.mkDerivation {
      name = "sshfp.json";

      publicKey = config.machine.ssh.key;
      passAsFile = singleton "publicKey";

      args = [ ];
      realBuilder = pkgs.writers.writeNu "sshfp.nu" /* nu */ ''
        ^${getExe' pkgs.openssh "ssh-keygen"} -r host -f $env.publicKeyPath
        | lines
        | parse "{owner} {class} SSHFP {algorithm} {fingerprintType} {fingerprint}"
        | into int algorithm fingerprintType
        | where fingerprintType == 2
        | select algorithm fingerprintType fingerprint
        | to json
        | save $env.out
      '';
    };
in
{
  systems.darwinSystem =
    fqdn: module:
    { inputs, ... }:
    let
      hostName = last fqdn;
      system = inputs.self.darwinConfigurations.${hostName};
    in
    {
      flake.dns = setAttrByPath fqdn {
        A = system.config.machine.ip.addresses4;
        AAAA = system.config.machine.ip.addresses6;
        SSHFP = optionals system.config.machine.ssh.enable <| sshfp system;
      };

      flake.darwinConfigurations.${hostName} = inputs.nix-darwin.lib.darwinSystem {
        lib = self;

        modules = [
          inputs.self.darwinModules.default

          module

          {
            networking = {
              inherit hostName;
              domain = fqdn |> init |> name.render;
            };

            machine.ssh = {
              hostName = fqdn |> name.render;
            };
          }
        ];
      };
    };

  systems.nixosSystem =
    fqdn: module:
    { inputs, ... }:
    let
      hostName = last fqdn;

      configuration = inputs.self.nixosConfigurations.${hostName};
    in
    {
      flake.dns = setAttrByPath fqdn {
        A = configuration.config.machine.ip.addresses4;
        AAAA = configuration.config.machine.ip.addresses6;
        SSHFP = optionals configuration.config.machine.ssh.enable <| sshfp configuration;
      };

      flake.nixosConfigurations.${hostName} = self.nixosSystem {
        modules = [
          inputs.self.nixosModules.default

          module

          {
            networking = {
              inherit hostName;
              domain = fqdn |> init |> name.render;
            };

            machine.ssh = {
              hostName = fqdn |> name.render;
            };
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

                DISKO_SKIP_SWAP=1 ^${configuration.config.system.build.diskoScript}

                # TODO: Make this a store path?
                (^nix copy
                  --no-check-sigs
                  --to $"local?root=($mountpoint)"
                  ${configuration.config.system.build.toplevel})

                (exec ${getExe nixos-install}
                  --no-channel-copy
                  --no-root-password
                  --system ${configuration.config.system.build.toplevel}
                  --root $mountpoint)
              }
            ''
          ) { };
        };
    };
}
