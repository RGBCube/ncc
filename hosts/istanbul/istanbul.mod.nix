{
  self,
  lib,
  ...
}:
let
  inherit (lib.lists) head singleton;
in
{
  flake.dns.software.hate =
    { config, ... }:
    {
      NS = [
        config.ns."0".FQDN
        config.ns."1".FQDN
      ];

      # TODO: v6 when I get one.
      ns."0".A = head self.machines.istanbul.ip.addresses4;

      # Here cause we need at least two. Will setup a different node later.
      ns."1".A = head self.machines.istanbul.ip.addresses4;
    };

  flake.machines.istanbul = {
    ip.addresses4 = singleton "149.0.17.169";
    ip.addresses6 = [ ];

    ssh = {
      enable = true;
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMCykEkiotbnje7b7Gg7f+fg58zOxRjNKuJO0z1eVrmF istanbul";
    };
  };

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

        system.services.authoritative.zones = singleton self.dns.software.hate;

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
