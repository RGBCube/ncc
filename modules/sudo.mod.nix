let
  extraConfig = # sudoers
  ''
    Defaults lecture = never
    Defaults pwfeedback
    Defaults env_keep += "DISPLAY EDITOR PATH"
  '';
in
{ self, ... }:
{
  nixosModules.sudo = {
    security.sudo.enable = false;

    security.sudo-rs = {
      enable = true;

      execWheelOnly = true;
      inherit extraConfig;
    };
  };

  nixosModules.sudo-server = {
    imports = [ self.nixosModules.sudo ];

    security.sudo.extraConfig = # sudoers
      ''
        Defaults timestamp_timeout = 0
      '';
  };

  darwinModules.sudo = {
    security.pam.services.sudo_local = {
      enable = true;
      touchIdAuth = true;
    };

    security.sudo = {
      inherit extraConfig;
    };
  };
}
