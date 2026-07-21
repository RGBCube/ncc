{ self, ... }:
{
  flake.homeModules.shell = self.homeModules.last;
  flake.homeModules.last =
    { pkgs, ... }:
    {
      xdg.config.files."nushell/config.nu".text = "source ${
        pkgs.writeText "last.nu" /* nu */ ''
          $env.config.hooks.display_output = {||
            tee { table --expand | print }
            # SQLiteDatabase doesn't support equality comparisions
            | try { if $in != null { $env.last = $in } }
          }

          # Retrieve the output of the last command.
          def _ []: nothing -> any {
            $env.last?
          }
        ''
      }";
    };
}
