{ self, inputs, ... }:
{
  flake.homeModules.sudo-run0-shim =
    { osConfig, ... }:
    {
      packages = [
        inputs.sudo-run0-shim.packages.${osConfig.nixpkgs.hostPlatform.system}.run0-sudo-shim
      ];
    };

  flake.nixosModules.sudo =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      security.sudo.enable = false;
      security.polkit.enable = true;

      home.extraModules = singleton self.homeModules.sudo-run0-shim;
    };

  flake.nixosModules.sudo-desktop = {
    security.polkit.extraConfig = # js
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
