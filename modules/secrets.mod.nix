{ inputs, ... }:
{
  flake.commonModules.secrets =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.modules) mkAliasOptionModule;
    in
    {
      imports = singleton <| mkAliasOptionModule [ "secrets" ] [ "age" "secrets" ];
    };

  flake.nixosModules.secrets =
    { config, lib, ... }:
    let
      inherit (lib.lists) head singleton;
    in
    {
      imports = singleton inputs.agenix.nixosModules.age;

      boot.initrd.availableKernelModules = {
        exfat = true;
        usb_storage = true;
        uas = true;
      };

      boot.supportedFilesystems = {
        exfat = true;
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

      age.identityPaths = singleton "/media/key/.secrets.key";

      services.openssh.hostKeys = singleton {
        type = "ed25519";
        path = head config.age.identityPaths;
      };
    };

  flake.darwinModules.secrets =
    { config, lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      imports = singleton inputs.agenix.darwinModules.age;

      age.identityPaths = singleton "/Users/${config.system.primaryUser}/.ssh/id"; # FIXME: This path shouldn't exist, but does because of agenix (sigh)
    };

  flake.homeModules.secrets-manager =
    { pkgs, lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      packages = singleton pkgs.ragenix;
    };
}
