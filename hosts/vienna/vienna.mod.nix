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
        inherit (lib.lists) singleton;
      in
      {
        imports = [
          self.nixosModules.server
          self.nixosModules.authoritative
        ];

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

        services.sessiond = {
          enable = true;
          user = "root";
        };

        persist.enable = true;

        disko.imageBuilder = {
          imageFormat = "qcow2";

          enableBinfmt = true;
          pkgs = import self.inputs.nixpkgs { system = "x86_64-linux"; };
          kernelPackages.kernel =
            config.disko.imageBuilder.pkgs.linuxPackages_latest
            |> (
              linuxPackages:
              config.disko.imageBuilder.pkgs.aggregateModules [
                linuxPackages.kernel
                linuxPackages.kernel.modules
                linuxPackages.bcachefs
              ]
            );
          extraRootModules = [
            "bcachefs"
            "vfat"
            "nls_cp437"
            "nls_iso8859-1"
          ];
        };

        disko.devices.disk."main" = {
          device = "/dev/disk/by-path/platform-4010000000.pcie-pci-0000:05:00.0";
          type = "disk";
          imageSize = "32G";

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

        hardware.reportPath = ./report.json;
        system.stateVersion = "26.05";
      }
    );
}
