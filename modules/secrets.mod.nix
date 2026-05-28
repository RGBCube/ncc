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
      inherit (lib.lists) any singleton;
      inherit (lib.modules) mkDefault mkIf mkMerge;
      inherit (lib.strings) hasPrefix;
    in
    {
      imports = singleton inputs.agenix.nixosModules.age;

      config = mkMerge [
        {
          # Agenix defaults identityPaths to openssh host keys, but
          # ssh.mod.nix derives those host keys from identityPaths.
          # Which is a cycle if you don't define identityPaths.
          age.identityPaths = mkDefault [ ];
        }

        (mkIf (config.age.identityPaths |> any (hasPrefix "/media/key/")) {
          boot.initrd.availableKernelModules = {
            exfat = true;
            usb_storage = true;
            uas = true;
          };

          fileSystems."/media/key" = {
            device = "/dev/disk/by-label/${config.networking.hostName}.s"; # .s as with .secrets it is really easy to hit the exfat label limit (11 characters).
            fsType = "exfat";
            options = [
              "ro"
              "umask=0077"
            ];
            neededForBoot = true;
          };
        })
      ];
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
