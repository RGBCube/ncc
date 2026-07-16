{ self, ... }:
{
  flake.darwinModules.default = self.darwinModules.syncthing;
  flake.darwinModules.syncthing =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      homebrew.casks = singleton "syncthing-app";

      system.defaults.CustomUserPreferences."com.github.xor-gate.syncthing-macosx" = {
        SUEnableAutomaticChecks = false;
        SUAutomaticallyUpdate = false;
        SUSendProfileInfo = false;
      };
    };

  # flake.nixosModules.syncthing =
  #   { lib, ... }:
  #   let
  #     inherit (lib.lists) singleton;
  #   in
  #   {
  #     # TODO
  #     persist.mountpoints = singleton "/var/lib/syncthing";

  #     services.syncthing.enable = true;
  #   };
}
