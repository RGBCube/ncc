{
  flake.nixosModules.boot =
    { config, lib, ... }:
    let
      inherit (lib.modules) mkDefault;
    in
    {
      boot.initrd.systemd = {
        enable = true;
        emergencyAccess = mkDefault config.users.users.root.hashedPasswordFile;
      };

      boot.loader.systemd-boot = {
        enable = true;
        # editor = false; # Security Theather. Hell, Security Cinema even.
      };

      boot.loader.efi.canTouchEfiVariables = true;
    };
}
