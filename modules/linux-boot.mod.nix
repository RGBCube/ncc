{
  flake.nixosModules.boot =
    { lib, ... }:
    let
      inherit (lib.modules) mkDefault;
    in
    {
      boot.initrd.systemd = {
        enable = true;
        # This is not a file path, it's a literal string, so we can't reference `root.hashedPasswordFile`.
        emergencyAccess = mkDefault true;
      };

      boot.loader.systemd-boot = {
        enable = true;
        # editor = false; # Security Theather. Hell, Security Cinema even.
      };

      boot.loader.efi.canTouchEfiVariables = true;
    };
}
