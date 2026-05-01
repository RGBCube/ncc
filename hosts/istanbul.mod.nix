{
  self,
  inputs,
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
          "zen-browser"
          "zulip"
        ]
        |> attrValues;
    };
in
{
  flake.nixosConfigurations.istanbul = lib.nixosSystem {
    modules = singleton {
      imports = modules;

      networking.hostName = "istanbul";

      boot.initrd.availableKernelModules.e1000e = true;

      disko.devices.disk."persist" = {
        device = "/dev/nvme0n1";
        type = "disk";
        content = {
          type = "gpt";

          partitions."boot" = {
            label = "boot";
            size = "1G";
            type = "EF00";

            content.type = "filesystem";
            content.format = "vfat";
            content.mountpoint = "/boot";
            content.mountOptions = [
              "fmask=0077"
              "dmask=0077"
            ];
          };

          partitions."persist" = {
            label = "persist";
            size = "100%";

            content.type = "bcachefs";
            content.filesystem = "persist";
            content.label = "persist";
          };
        };
      };

      disko.devices.nodev."root" = {
        fsType = "tmpfs";
        mountpoint = "/";
        mountOptions = [
          "defaults"
          "size=25%"
          "mode=755"
        ];
      };

      persist.enable = true;
      disko.devices.bcachefs_filesystems."persist" = {
        type = "bcachefs_filesystem";
        extraFormatArgs = [
          "--compression=zstd:9"
          "--background_compression=zstd:9"
          "--block_size=4096"
        ];

        mountpoint = "/media/persist";
        mountOptions = [
          "lazytime"
          "x-systemd.requires-mounts-for=/media/key"
        ];

        passwordFile = "/media/key/.bcachefs.key";
      };

      hardware.report = ./istanbul.report.json;
      system.stateVersion = "25.11";
    };
  };

  flake.nixosConfigurations.istanbul-installer = lib.nixosSystem {
    modules = singleton (
      { pkgs, ... }:
      let
        inherit (lib.lists) singleton;
        inherit (lib.meta) getExe;

        istanbul = self.nixosConfigurations.istanbul;
      in
      {
        imports = modules ++ singleton self.nixosModules.iso;

        environment.etc."install-closure".source = pkgs.closureInfo {
          rootPaths = [
            istanbul.config.system.build.toplevel
            istanbul.config.system.build.diskoScript
            istanbul.config.system.build.diskoScript.drvPath
            istanbul.pkgs.stdenv.drvPath
            (istanbul.pkgs.closureInfo { rootPaths = [ ]; }).drvPath
          ];
        };

        environment.systemPackages = [
          (pkgs.writeShellScriptBin "install-istanbul" /* bash */ ''
            set -euo pipefail

            exec ${
              getExe inputs.disko.packages.${pkgs.stdenv.hostPlatform.system}.disko-install
            } --flake "${self}#istanbul" --disk persist "${istanbul.config.disko.devices.disk.persist.device}"
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
