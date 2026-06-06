{ lib, self, ... }:
let
  inherit (lib.lists) singleton;
  inherit (lib.trivial) flip;
  inherit (lib.attrsets) attrValues;
in
{
  nixosSystem =
    hostName: module:
    let
      nixosConfig = lib.nixosSystem {
        specialArgs.lib = lib;

        modules = [
          module

          {
            networking.hostName = hostName;
          }
        ];
      };
    in
    {
      flake.nixosConfigurations.${hostName} = nixosConfig;

      flake.nixosConfigurations."${hostName}-installer" = lib.nixosSystem {
        specialArgs.lib = lib;

        modules =
          attrValues self.commonModules
          ++ (
            self.nixosModules
            |> flip removeAttrs [
              "bluetooth-gui"
              "fonts"
              "helium"
              "iso"
              "linux-kernel-desktop"
              "packages-debugging-gui"
              "sound"
              "steam"
              "sudo-desktop"
            ]
            |> attrValues
          )
          ++ singleton (
            { lib, pkgs, ... }:
            let
              inherit (lib.lists) singleton;
              inherit (lib.meta) getExe;
              inherit (lib.modules) mkForce;
              inherit (lib.trivial) flip;
              inherit (lib.attrsets) attrValues;
            in
            {
              imports = singleton self.nixosModules.iso;

              networking.hostName = "${hostName}-installer";

              age.identityPaths = singleton "/etc/ssh/ssh_host_ed25519_key";
              boot.initrd.network.ssh.enable = mkForce false;

              home.extraModules =
                self.homeModules
                |> flip removeAttrs [
                  "cinny"
                  "darwin-wm"
                  "discord"
                  "file-explorer"
                  "ghostty"
                  "helium"
                  "helix-desktop"
                  "keepassxc"
                  "krita"
                  "libreoffice"
                  "obs-studio"
                  "signal-desktop"
                  "ssh-client-desktop"
                  "thunderbird"
                  "torrent-client"
                  "video-player"
                  "whatsapp"
                  "zulip"
                ]
                |> attrValues;

              environment.systemPackages = [
                self.packages.${pkgs.stdenv.hostPlatform.system}."installer-${hostName}"

                (pkgs.writeShellScriptBin "generate-report" /* bash */ ''
                  set -euo pipefail

                  exec ${getExe pkgs.nixos-facter}
                '')
              ];

              nixpkgs.hostPlatform = nixosConfig.config.nixpkgs.hostPlatform;
              system.stateVersion = nixosConfig.config.system.stateVersion;
            }
          );
      };

      perSystem =
        { pkgs, ... }:
        {
          packages."installer-${hostName}" = pkgs.callPackage (
            {
              lib,
              nushell,
              nixos-install,
              writeScriptBin,
            }:
            let
              inherit (lib.meta) getExe getExe';
            in
            writeScriptBin "install-${hostName}" /* nu */ ''
              #!${getExe nushell}
              #

              def main [] {
                let mountpoint = "/mnt"

                mkdir $mountpoint
                # bcachefs format refuses unless the mount-point parent is 0755.
                ^${getExe' pkgs.uutils-coreutils-noprefix "chmod"} 755 $mountpoint

                DISKO_SKIP_SWAP=1 ^${nixosConfig.config.system.build.diskoScript}

                # TODO: Make this a store path?
                (^nix copy
                  --no-check-sigs
                  --to $"local?root=($mountpoint)"
                  ${nixosConfig.config.system.build.toplevel})

                (^${getExe nixos-install}
                  --no-channel-copy
                  --no-root-password
                  --system ${nixosConfig.config.system.build.toplevel}
                  --root $mountpoint)
              }
            ''
          ) { };
        };
    };
}
