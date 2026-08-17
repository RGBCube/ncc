{ self, lib, ... }:
let
  inherit (lib.lists) singleton;
in
{
  flake.nixosModules.default = self.nixosModules.kmscon;
  flake.nixosModules.kmscon =
    { pkgs, lib, ... }:
    let
      inherit (lib.meta) getExe;
    in
    {
      imports = singleton self.nixosModules.sessiond;

      security.pam.services.vlock.enable = true;

      services.sessiond.instancedCommand = [
        (getExe pkgs.kmscon)
        "--no-switchvt"
        "--login"
        "--"
        (pkgs.writers.writeNu "shell-locked" /* nu */ ''
          ^${getExe pkgs.vlock}
          exec $env.SHELL
        '')
      ];
    };
}
