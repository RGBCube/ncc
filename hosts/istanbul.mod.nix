{
  self,
  inputs,
  keys,
  lib,
  ...
}:
let
  inherit (lib.attrsets) attrValues removeAttrs;
  inherit (lib.lists) singleton;

  modules =
    attrValues (
      removeAttrs self.nixosModules [
        "bluetooth-gui"
        "debugging-gui"
        "fonts"
        "helium"
        "linux-kernel-desktop"
        "sound"
        "steam"
        "sudo-desktop"
        "theme"
      ]
    )
    ++ singleton {
      home.extraModules =
        attrValues
        <| removeAttrs self.homeModules [
          # Already added by the home nixosModule.
          "home"
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
        ];
    };
in
{
  flake.nixosConfigurations.istanbul = lib.nixosSystem {
    specialArgs = { inherit self inputs keys; };

    modules =
      modules
      ++ singleton (
        {
          config,
          lib,
          utils,
          ...
        }:
        let
          inherit (lib.meta) getExe;
          inherit (lib.modules) mkForce;
          inherit (utils) escapeSystemdPath;
        in
        {
          networking.hostName = "istanbul";

          boot.loader.systemd-boot.enable = true;
          boot.loader.systemd-boot.editor = false;
          boot.loader.efi.canTouchEfiVariables = true;

          boot.initrd.systemd.enable = true;

          boot.supportedFilesystems = {
            bcachefs = true;
            exfat = true;
          };

          boot.initrd.availableKernelModules = {
            exfat = true;
            nvme = true;
            sd_mod = true;
            uas = true;
            usb_storage = true;
            xhci_pci = true;
          };

          fileSystems."/" = {
            device = "none";
            fsType = "tmpfs";
            options = [
              "defaults"
              "size=25%"
              "mode=755"
            ];
          };

          fileSystems."/media/key" = {
            device = "/dev/disk/by-label/fatih";
            fsType = "exfat";
            options = [
              "ro"
              "umask=0077"
            ];
            neededForBoot = true;
          };

          fileSystems."/media/persist".options = singleton "x-systemd.requires-mounts-for=/media/key";
          boot.initrd.systemd.services."unlock-bcachefs-${escapeSystemdPath "/media/persist"}".script =
            mkForce
              /* bash */ ''
                ${getExe config.boot.bcachefs.package} unlock --file /media/key/.bcachefs.key ${
                  config.fileSystems."/media/persist".device
                }
              '';

          disko.devices.disk."default" = {
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

                content.type = "bcachefs";
                content.filesystem = "root";
              };
            };
          };

          disko.devices.bcachefs_filesystems."root" = {
            type = "bcachefs_filesystem";
            extraFormatArgs = [
              "--compression=zstd:9"
              "--background_compression=zstd:9"
              "--block_size=4096"
            ];

            mountpoint = "/media/persist";
            passwordFile = "/media/key/.bcachefs.key";

            subvolumes."nix".mountpoint = "/nix";
          };

          nixpkgs.hostPlatform = "x86_64-linux";
          system.stateVersion = "25.11";
        }
      );
  };

  flake.nixosConfigurations.istanbul-installer = lib.nixosSystem {
    specialArgs = { inherit self inputs keys; };

    modules =
      modules
      ++ singleton (
        { pkgs, ... }:
        let
          inherit (lib.lists) singleton;
          inherit (lib.meta) getExe;
          inherit (lib.modules) mkForce;

          istanbul = self.nixosConfigurations.istanbul;
          closureInfo = pkgs.closureInfo {
            rootPaths = [
              istanbul.config.system.build.toplevel
              istanbul.config.system.build.diskoScript
              istanbul.config.system.build.diskoScript.drvPath
              istanbul.pkgs.stdenv.drvPath
              (istanbul.pkgs.closureInfo { rootPaths = [ ]; }).drvPath
            ];
          };
        in
        {
          imports = singleton <| inputs.nixpkgs + /nixos/modules/installer/cd-dvd/installation-cd-minimal.nix;

          users.users.nixos.isNormalUser = mkForce false;
          services.getty.autologinUser = mkForce "root";

          boot.supportedFilesystems = {
            bcachefs = true;
            exfat = true;
          };

          services.udev.extraRules = ''
            ACTION=="add", ENV{ID_FS_LABEL}=="fatih", TAG+="systemd", ENV{SYSTEMD_WANTS}="media-key.mount"
          '';

          systemd.mounts = singleton {
            what = "LABEL=fatih";
            where = "/media/key";
            type = "exfat";
            options = "ro,umask=0077";
          };

          environment.etc."install-closure".source = "${closureInfo}/store-paths";

          environment.systemPackages =
            singleton
            <| pkgs.writeShellScriptBin "install-istanbul" /* bash */ ''
              set -euo pipefail

              exec ${
                getExe inputs.disko.packages.${pkgs.stdenv.hostPlatform.system}.disko-install
              } --flake "${self}#istanbul" --disk default "${istanbul.config.disko.devices.disk.default.device}"
            '';

          nixpkgs.hostPlatform = "x86_64-linux";
          system.stateVersion = "25.11";
        }
      );
  };
}
