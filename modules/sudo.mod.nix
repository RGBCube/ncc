{ inputs, self, ... }:
{
  flake.homeModules.sudo-run0-shim =
    { osConfig, lib, ... }:
    let
      inherit (lib.modules) mkIf;
    in
    {
      packages = mkIf osConfig.nixpkgs.hostPlatform.isLinux [
        inputs.sudo-run0-shim.packages.${osConfig.nixpkgs.hostPlatform.system}.run0-sudo-shim
      ];
    };

  flake.nixosModules.default = self.nixosModules.sudo;
  flake.nixosModules.sudo = {
    security.sudo.enable = false;
    security.polkit.enable = true;

    home.extraModules = [ self.homeModules.sudo-run0-shim ];
  };

  flake.nixosModules.desktop = self.nixosModules.sudo-desktop;
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
