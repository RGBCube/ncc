{
  flake.homeModules.torrent-client =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      inherit (lib.modules) mkIf;
      inherit (lib.trivial) const flip;
      inherit (lib.attrsets) genAttrs;
    in
    {
      xdg.mime-apps.default-applications = mkIf osConfig.nixpkgs.hostPlatform.isLinux
        <| flip genAttrs (const "org.qbittorrent.qBittorrent.desktop") [
          "application/x-bittorrent"
          "x-scheme-handler/magnet"
        ];

      packages = [
        pkgs.qbittorrent
      ];
    };
}
