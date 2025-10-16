{
  homeModules.torrent-client = { pkgs, ... }: {
    # TODO: xdg.mime

    packages = [
      pkgs.qbittorrent
    ];
  };
}
