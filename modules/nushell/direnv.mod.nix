{ self, ... }:
{
  flake.homeModules.shell = self.homeModules.direnv;
  flake.homeModules.direnv =
    { lib, pkgs, ... }:
    let
      inherit (lib.modules) mkBefore;
      inherit (lib.lists) singleton;
    in
    {
      packages = singleton pkgs.direnv;

      xdg.config.files."direnv/lib/nix-direnv.sh".source = "${pkgs.nix-direnv}/share/nix-direnv/direnvrc";

      xdg.config.files."nushell/config.nu".text = mkBefore "source ${
        pkgs.writeText "direnv-hook.nu" /* nu */ ''
          $env.config.hooks.env_change.PWD = [
            { ||
              ^direnv export json | from json | default {} | load-env
            }
          ]
        ''
      }";
    };
}
