{ self, ... }:
{
  flake.homeModules.shell = self.homeModules.yazi;
  flake.homeModules.yazi =
    { lib, pkgs, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      packages = singleton pkgs.yazi;

      xdg.config.files."yazi/keymap.toml".generator = pkgs.writers.writeTOML "yazi-keymap.toml";
      xdg.config.files."yazi/keymap.toml".value = {
        mgr.prepend_keymap = singleton {
          on = "!";
          run = /* sh */ ''shell --block "$SHELL"'';
          desc = "Open shell here";
        };
      };
    };
}
