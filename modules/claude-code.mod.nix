{
  homeModules.claude-code =
    { pkgs, ... }:
    {
      packages = [
        pkgs.claude-code 
      ];
    };
}
