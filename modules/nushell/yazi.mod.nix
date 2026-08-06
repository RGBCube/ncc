{ self, ... }:
{
  flake.homeModules.shell = self.homeModules.yazi;
  flake.homeModules.yazi =
    { lib, pkgs, ... }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe;
    in
    {
      packages = singleton pkgs.yazi;

      xdg.config.files."yazi/yazi.toml".generator = pkgs.writers.writeTOML "yazi-config.toml";
      xdg.config.files."yazi/yazi.toml".value = {
        mgr.sort_by = "natural";
        mgr.sort_sensitive = false;
        mgr.sort_dir_first = true;
        mgr.sort_translit = true;

        mgr.show_hidden = true;
        mgr.show_symlink = true;

        mgr.linemode = "size";

        preview.wrap = "yes";
      };

      xdg.config.files."yazi/keymap.toml".generator = pkgs.writers.writeTOML "yazi-keymap.toml";
      xdg.config.files."yazi/keymap.toml".value = {
        mgr.prepend_keymap = singleton {
          on = "!";
          run = /* sh */ ''shell --block "$SHELL"'';
          desc = "Open shell here";
        };
      };

      xdg.config.files."nushell/config.nu".text = "source ${
        pkgs.writeText "yazi.nu" /* nu */ ''
          def --env yazi [...arguments: string]: nothing -> nothing {
            let cwd = ${getExe pkgs.yazi} --cwd-file /dev/stdout ...$arguments | str trim
            if $cwd != "" and $cwd != $env.PWD { cd $cwd }
          }
        ''
      }";
    };
}
