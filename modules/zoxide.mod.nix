{
  homeModules.zoxide = {
    programs.zoxide = {
      enable = true;

      flags = [
        "--cmd"
        "cd"
      ];

      integrations.nushell.enable = true;
    };
  };
}
