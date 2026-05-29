{
  self,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
in
{
  imports =
    singleton
    <| lib.systems.nixosSystem "vienna" (
      { config, lib, ... }:
      let
        inherit (lib.attrsets) attrValues removeAttrs;
        inherit (lib.lists) singleton;
        inherit (lib.trivial) flip;
      in
      {

        imports =
          attrValues self.commonModules
          ++ (
            self.nixosModules
            |> flip removeAttrs [
              "bluetooth-gui"
              "fonts"
              "helium"
              "iso"
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

        networking = {
          macPolicy = "hostname";

          defaultGateway = {
            address = "152.53.0.1";
            interface = "enp4s0";
          };
          defaultGateway6 = {
            address = "fe80::1";
            interface = "enp4s0";
          };

          interfaces.enp4s0 = {
            ipv4.addresses = singleton {
              address = "152.53.2.105";
              prefixLength = 22;
            };
            ipv6.addresses = singleton {
              address = "2a0a:4cc0:0:12d9::1";
              prefixLength = 64;
            };
          };
        };

        persist.mountpoints = singleton "/var/lib/secrets";
        age.identityPaths = singleton "/var/lib/secrets/key";

        secrets.password.file = ./password.age;
        users.users.root.hashedPasswordFile = config.secrets.password.path;

        persist.enable = true;

        disko.devices.disk."main" = {
          device = "/dev/disk/by-path/platform-4010000000.pcie-pci-0000:05:00.0";
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

          content.partitions."swap" = {
            priority = 150;
            size = "16G";
            type = "8200";

            content.type = "swap";
            content = {
              discardPolicy = "both";
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
        system.stateVersion = "26.05";
      }
    );
}
