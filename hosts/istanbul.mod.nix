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
    modules = singleton (
      { config, ... }:
      {
        imports = modules;

        networking.hostName = "istanbul";

        boot.initrd.availableKernelModules.e1000e = true;

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
        persist.passwordFile = "/media/key/.bcachefs.key";

        disko.devices.disk."nvme0n1" = disk: {
          device = "/dev/${disk.config.name}";
          type = "disk";

          content.type = "gpt";

          content.partitions."boot" = {
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

          content.partitions."bcachefs" = {
            size = "100%";

            content.type = "bcachefs";
            content.filesystem = config.persist.filesystemName;
            content.label = "nvme.nvme0";
          };
        };

        hardware.report = ./istanbul.report.json;
        system.stateVersion = "25.11";
      }
    );
  };

  flake.nixosConfigurations.istanbul-installer = lib.nixosSystem {
    modules = singleton (
      { pkgs, ... }:
      let
        inherit (lib.attrsets) mapAttrsToList;
        inherit (lib.lists) singleton;
        inherit (lib.meta) getExe;
        inherit (lib.strings) concatStringsSep;

        istanbul = self.nixosConfigurations.istanbul;
      in
      {
        imports = modules ++ singleton self.nixosModules.iso;

        environment.etc."install-closure".source = pkgs.closureInfo {
          rootPaths = [
            istanbul.config.system.build.toplevel
            istanbul.config.system.build.diskoScript
          ];
        };

        environment.systemPackages = [
          (pkgs.writeShellScriptBin "install-istanbul" /* bash */ ''
            set -euo pipefail

            exec ${
              getExe inputs.disko.packages.${pkgs.stdenv.hostPlatform.system}.disko-install
            } --flake "${self}#istanbul" ${
              istanbul.config.disko.devices.disk
              |> mapAttrsToList (name: disk: ''--disk ${name} "${disk.device}"'')
              |> concatStringsSep " "
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
