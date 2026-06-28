{
  flake.darwinModules.use-xdg-dirs =
    { lib, ... }:
    let
      inherit (lib.modules) mkAfter;
    in
    {
      # On darwin, the login shell has to be zsh, so set ZDOTDIR before the user
      # configuration is read.
      environment.etc."zshenv".text = mkAfter /* zsh */ ''
        export ZDOTDIR="''${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
      '';
    };

  flake.homeModules.use-xdg-dirs =
    {
      config,
      pkgs,
      ...
    }:
    {
      xdg.data.files."android".type = "directory";
      environment.sessionVariables.ANDROID_USER_HOME = "${config.xdg.data.directory}/android";
      programs.nushell.extraConfig = "source ${
        pkgs.writeText "adb-wrapper.nu" /* nu */ ''
          def --wrapped adb [...arguments] {
            with-env { HOME: "${config.xdg.data.directory}/android" } { ^adb ...$arguments }
          }
        ''
      }\n";

      xdg.config.files."aws".type = "directory";
      environment.sessionVariables.AWS_CONFIG_FILE = "${config.xdg.config.directory}/aws/config";
      environment.sessionVariables.AWS_SHARED_CREDENTIALS_FILE = "${config.xdg.config.directory}/aws/credentials";

      xdg.config.files."codex".type = "directory";
      environment.sessionVariables.CODEX_HOME = "${config.xdg.config.directory}/codex";

      xdg.config.files."claude-code".type = "directory";
      environment.sessionVariables.CLAUDE_CONFIG_DIR = "${config.xdg.config.directory}/claude-code";

      files.".ssh/config".text =
        # sshclientconfig
        ''
          Include ${config.xdg.config.directory}/ssh/config
        '';

      xdg.data.files."zsh".type = "directory";
      environment.sessionVariables.ZDOTDIR = "${config.xdg.config.directory}/zsh";

      xdg.data.files."cargo".type = "directory";
      environment.sessionVariables.CARGO_HOME = "${config.xdg.data.directory}/cargo";

      xdg.data.files."go".type = "directory";
      environment.sessionVariables.GOPATH = "${config.xdg.data.directory}/go";

      xdg.data.files."gradle".type = "directory";
      environment.sessionVariables.GRADLE_USER_HOME = "${config.xdg.data.directory}/gradle";

      xdg.config.files."ripgrep".type = "directory";
      environment.sessionVariables.RIPGREP_CONFIG_PATH = "${config.xdg.config.directory}/ripgrep/config";

      xdg.state.files."sqlite".type = "directory";
      environment.sessionVariables.SQLITE_HISTORY = "${config.xdg.state.directory}/sqlite/history";

      xdg.state.files."zsh".type = "directory";
      environment.sessionVariables.HISTFILE = "${config.xdg.state.directory}/zsh/history";

      xdg.state.files."less".type = "directory";
      environment.sessionVariables.LESSHISTFILE = "${config.xdg.state.directory}/less/history";

      xdg.state.files."node".type = "directory";
      environment.sessionVariables.NODE_REPL_HISTORY = "${config.xdg.state.directory}/node/history";

      xdg.state.files."python".type = "directory";
      environment.sessionVariables.PYTHON_HISTORY = "${config.xdg.state.directory}/python/history";
    };
}
