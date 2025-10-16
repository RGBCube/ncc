{
  homeModules.zulip =
    { pkgs, ... }:
    {
      packages = [
        pkgs.zulip
      ];
    };
}
