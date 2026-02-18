{
  flake.homeModules.use-xdg-dirs =
    {
      config,
      osConfig,
      lib,
      ...
    }:
    let
      inherit (lib.modules) mkBefore mkIf;
    in
    {
      environment.sessionVariables.AWS_CONFIG_FILE = "${config.xdg.config.directory}/aws/config";
      environment.sessionVariables.AWS_SHARED_CREDENTIALS_FILE = "${config.xdg.config.directory}/aws/credentials";
      xdg.config.files."aws/.keep".text = "";

      environment.sessionVariables.ZDOTDIR = "${config.xdg.config.directory}/zsh";
      xdg.config.files."zsh/.zshrc".text =
        mkIf osConfig.nixpkgs.hostPlatform.isDarwin
        <| mkBefore /* zsh */ ''
          autoload -Uz compinit
          compinit -d "${config.xdg.cache.directory}/zsh/zcompdump-$ZSH_VERSION"
        '';
      files.".zshrc".text = mkIf osConfig.nixpkgs.hostPlatform.isDarwin /* zsh */ ''
        [[ -f "${config.xdg.config.directory}/zsh/.zshrc" ]] && source "${config.xdg.config.directory}/zsh/.zshrc"
      '';
      xdg.cache.files."zsh/.keep".text = "";

      environment.sessionVariables.CARGO_HOME = "${config.xdg.data.directory}/cargo";
      xdg.data.files."cargo/.keep".text = "";

      environment.sessionVariables.GOPATH = "${config.xdg.data.directory}/go";
      xdg.data.files."go/.keep".text = "";

      environment.sessionVariables.SQLITE_HISTORY = "${config.xdg.state.directory}/sqlite/history";
      xdg.state.files."sqlite/.keep".text = "";

      environment.sessionVariables.HISTFILE = "${config.xdg.state.directory}/zsh/history";
      xdg.state.files."zsh/.keep".text = "";

      environment.sessionVariables.LESSHISTFILE = "${config.xdg.state.directory}/less/history";
      xdg.state.files."less/.keep".text = "";

      environment.sessionVariables.NODE_REPL_HISTORY = "${config.xdg.state.directory}/node/history";
      xdg.state.files."node/.keep".text = "";

      environment.sessionVariables.PYTHON_HISTORY = "${config.xdg.state.directory}/python/history";
      xdg.state.files."python/.keep".text = "";
    };
}
