{ self, ... }:
{
  flake.homeModules.shell = self.homeModules.direnv;
  flake.homeModules.direnv =
    { pkgs, ... }:
    {
      packages = [
        pkgs.direnv
        pkgs.nix-direnv
      ];

      programs.direnv = {
        enable = true;

        integrations.nix-direnv.enable = true;
        integrations.nushell.enable = true;
      };
    };
}
