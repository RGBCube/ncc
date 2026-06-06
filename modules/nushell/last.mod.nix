{
  flake.homeModules.last =
    { pkgs, ... }:
    {
      programs.nushell.extraConfig = "source ${
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
      }\n";
    };
}
