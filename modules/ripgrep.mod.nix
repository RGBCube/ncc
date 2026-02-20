{ self, ... }:
{
  flake.homeModules.ripgrep =
    { lib, pkgs, ... }:
    {
      packages = [
        pkgs.ripgrep
      ];

      xdg.config.files."ripgrep/ripgreprc".generator = self.lib.generators.toCliFlagList;
      xdg.config.files."ripgrep/ripgreprc".value = {
        line-number = true;
        smart-case = true;
      };
    };
}
