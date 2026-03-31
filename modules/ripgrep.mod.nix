{ self, ... }:
{
  flake.homeModules.ripgrep =
    { lib, pkgs, ... }:
    {
      packages = [
        pkgs.ripgrep
      ];

      xdg.config.files."ripgrep/config".generator = self.lib.generators.toCliFlagList;
      xdg.config.files."ripgrep/config".value = {
        line-number = true;
        smart-case = true;
      };
    };
}
