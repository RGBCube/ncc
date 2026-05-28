{
  self,
  lib,
  ...
}:
let
  inherit (lib.attrsets) attrValues removeAttrs;
  inherit (lib.lists) singleton;
  inherit (lib.trivial) flip;

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
    ++ singleton {
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
    };
in
{
  flake.nixosConfigurations.istanbul = lib.nixosSystem {
    modules = singleton (
      { config, ... }:
      {
        imports = modules;

        networking.hostName = "istanbul";
        networking.macPolicy = "hostname";

        boot.initrd.availableKernelModules.e1000e = true;

        secrets.password.file = ./password.age;
        users.users.root.hashedPasswordFile = config.secrets.password.path;

        persist.enable = true;
        persist.passwordFile = "/media/key/.bcachefs.key";

        disko.devices.disk."nvme0n1" = disk: {
          device = "/dev/${disk.config.name}";
          type = "disk";

          content.type = "gpt";

          content.partitions."boot" = {
            priority = 100;
            size = "1G";
            type = "EF00";

            content.type = "filesystem";
            content = {
              format = "vfat";
            };
          };

          content.partitions."bcachefs" = {
            priority = 200;
            size = "100%";

            content.type = "bcachefs";
            content = {
              filesystem = config.persist.filesystemName;
              label = "nvme.nvme0";
            };
          };
        };

        hardware.report = ./report.json;
        system.stateVersion = "25.11";
      }
    );
  };

  flake.nixosConfigurations.istanbul-installer = lib.nixosSystem {
    modules = singleton (
      { pkgs, ... }:
      let
        inherit (lib.lists) singleton;
        inherit (lib.meta) getExe;

        istanbul = self.nixosConfigurations.istanbul;

        toplevel = istanbul.config.system.build.toplevel;
      in
      {
        imports = modules ++ singleton self.nixosModules.iso;

        boot.supportedFilesystems = istanbul.config.boot.supportedFilesystems;

        environment.systemPackages = [
          (pkgs.writeScriptBin "install-istanbul" /* nu */ ''
            #!${getExe pkgs.nushell}
            #

            def main [] {
              if (^id --user | into int) != 0 {
                error make { msg: "install-istanbul must run as root" }
              }

              let mountpoint = "/mnt"

              mkdir $mountpoint
              # bcachefs format refuses unless the mount-point parent is 0755.
              ^chmod 755 $mountpoint

              DISKO_SKIP_SWAP=1 ^${istanbul.config.system.build.diskoScript}

              (^nix copy
                --no-check-sigs
                --to $"local?root=($mountpoint)"
                ${toplevel})

              (^${getExe pkgs.nixos-install}
                --no-channel-copy
                --no-root-password
                --system ${toplevel}
                --root $mountpoint)
            }
          '')

          (pkgs.writeShellScriptBin "generate-facter-report" /* bash */ ''
            set -euo pipefail

            exec ${getExe pkgs.nixos-facter}
          '')
        ];

        nixpkgs.hostPlatform = "x86_64-linux";
        system.stateVersion = "25.11";
      }
    );
  };
}
