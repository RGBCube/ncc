{ self, ... }:
{
  flake.nixosModules.default = self.nixosModules.sudo;
  flake.nixosModules.sudo = {
    security.sudo.enable = false;
    security.polkit.enable = true;
  };

  flake.nixosModules.desktop = self.nixosModules.sudo-auth-keep;
  flake.nixosModules.polkit-auth-keep = {
    security.polkit.extraConfig = # javascript
      ''
        polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.policykit.exec") {
            return polkit.Result.AUTH_ADMIN_KEEP;
          }
        });

        polkit.addRule(function(action, subject) {
          if (action.id.indexOf("org.freedesktop.systemd1.") == 0) {
            return polkit.Result.AUTH_ADMIN_KEEP;
          }
        });
      '';
  };

  flake.darwinModules.default = self.darwinModules.sudo;
  flake.darwinModules.sudo = {
    security.pam.services.sudo_local = {
      enable = true;
      touchIdAuth = true;
    };

    security.sudo.extraConfig = # sudoers
      ''
        Defaults lecture = never
        Defaults pwfeedback
        Defaults env_keep += "EDITOR PATH"
      '';
  };
}
