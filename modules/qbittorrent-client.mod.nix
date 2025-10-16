{
  homeModules.qbittorrent-client =
    { pkgs, ... }:
    {
      packages = [
        pkgs.qbittorrent 
      ];
    };
}
