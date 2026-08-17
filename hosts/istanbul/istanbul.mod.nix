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
    <| lib.systems.nixosSystem "istanbul" (
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
        };

        boot.initrd.availableKernelModules.e1000e = true;

        age.identityPaths = singleton "/media/key/.secrets.key";

        secrets.password.file = ./password.age;
        users.users.root.hashedPasswordFile = config.secrets.password.path;

        services.sessiond = {
          enable = true;
          user = "root";
        };

        persist.enable = true;
        persist.passwordFile = "/media/key/.bcachefs.key";

        disko.devices.disk."main" = {
          device = "/dev/disk/by-id/nvme-SKHynix_HFS256GDE9X081N_FYACN05061040CN2U";
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

        hardware.reportPath = ./report.json;
        system.stateVersion = "25.11";
      }
    );
}
