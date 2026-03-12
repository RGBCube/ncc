{
  self,
  inputs,
  lib,
  ...
}:
let
  inherit (lib.attrsets) attrValues removeAttrs;
  inherit (lib.lists) singleton;
in
{
  flake.nixosConfigurations.istanbul = lib.nixosSystem {
    specialArgs = { inherit self inputs; };

    modules = singleton (
      {
        config,
        lib,
        utils,
        ...
      }:
      let
        inherit (lib.meta) getExe;
        inherit (lib.modules) mkAfter mkForce;
        inherit (utils) escapeSystemdPath;
      in
      {
        imports =
          attrValues
          <| removeAttrs self.nixosModules [
            "bluetooth"
            "file-explorer"
            "fonts"
            "helium"
            "linux-kernel-desktop"
            "sound"
            "steam"
            "sudo-desktop"
            "theme"
          ];

        home.extraModules =
          attrValues
          <| removeAttrs self.homeModules [
            "cinny"
            "darwin-wm"
            "discord"
            "ghostty"
            "helium"
            "helix-desktop"
            "keepassxc"
            "krita"
            "libreoffice"
            "obs-studio"
            "signal-desktop"
            "ssh-client-desktop"
            "theme"
            "thunderbird"
            "torrent-client"
            "video-player"
            "whatsapp"
            "zen-browser"
            "zulip"
          ];

        networking.hostName = "istanbul";

        boot.supportedFilesystems = [
          "bcachefs"
          "exfat"
        ];

        boot.initrd.availableKernelModules = [
          "exfat"
          "nvme"
          "sd_mod"
          "uas"
          "usb_storage"
          "xhci_pci"
        ];
        boot.initrd.systemd.enable = true;
        boot.initrd.systemd.mounts = singleton {
          what = "LABEL=fatih";
          where = "/media/key";
          type = "exfat";
          options = "ro,umask=0077";
        };

        fileSystems."/".options = mkAfter <| singleton "x-systemd.requires-mounts-for=/media/key";
        boot.initrd.systemd.services."unlock-bcachefs-${escapeSystemdPath "/"}".script =
          mkForce # Force, because by default NixOS will do clevis or interactive authentication.
          <| /* bash */ ''
            ${getExe config.boot.bcachefs.package} unlock --file /media/key/.bcachefs.key ${config.fileSystems."/".device}
          '';

        disko.devices.disk.default = {
          device = "/dev/nvme0n1";
          type = "disk";
          content = {
            type = "gpt";

            partitions.boot = {
              label = "boot";
              size = "1G";
              type = "EF00";

              content.type = "filesystem";
              content.format = "vfat";
              content.mountpoint = "/boot";
              content.mountOptions = [
                "fmask=0022"
                "dmask=0022"
              ];
            };

            partitions.root = {
              label = "root";
              size = "100%";

              content.type = "filesystem";
              content.format = "bcachefs";
              content.mountpoint = "/";
              content.extraArgs = [
                "--compression=zstd:9"
                "--background_compression=zstd:9"
                "--encrypted"
                "--passphrase_file=/media/key/.bcachefs.key"
              ];
            };
          };
        };

        nixpkgs.hostPlatform = "x86_64-linux";
        system.stateVersion = "25.11";
      }
    );
  };
}
