{
  flake.homeModules.difftastic =
    { lib, pkgs, ... }:
    let
      inherit (lib.meta) getExe;
      inherit (lib.generators) toINI toTOML;
      inherit (lib.lists) singleton;

      difft = pkgs.writeShellScriptBin "difft" /* bash */ ''
        exec ${getExe pkgs.difftastic} --background dark "$@"
      '';
    in
    {
      packages = singleton difft;

      # GIT INTEGRATION
      xdg.config.file."git/config".generator = toINI { };
      xdg.config.file."git/config".value = {
        diff.external = getExe difft;
        diff.tool = "difftastic";
        difftool.difftastic.cmd = # sh
          ''${getExe difft} "$LOCAL" "$REMOTE"'';
      };

      # JUJUTSU INTEGRATION
      xdg.config.file."jj/config.toml".generator = toTOML;
      xdg.config.file."jj/config.toml".value.ui.diff-formatter = [
        (getExe difft)
        "--color"
        "always"
        "$left"
        "$right"
      ];
    };
}
