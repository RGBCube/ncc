{ self, ... }:
{
  flake.homeModules.cli = self.homeModules.ripgrep;
  flake.homeModules.ripgrep =
    { lib, pkgs, ... }:
    let
      inherit (lib.cli) toCommandLine;
      inherit (lib.strings) concatLines;
    in
    {
      packages = [
        pkgs.ripgrep
      ];

      xdg.config.files."ripgrep/config".generator =
        attrs:
        attrs
        |> toCommandLine (name: {
          option = "--${name}";
          sep = null;
          explicitBool = false;
        })
        |> concatLines;
      xdg.config.files."ripgrep/config".value = {
        line-number = true;
        smart-case = true;
      };
    };
}
