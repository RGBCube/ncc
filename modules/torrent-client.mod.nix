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
      inherit (lib.generators) toINI;
    in
    {
      xdg.mime-apps.default-applications =
        mkIf osConfig.nixpkgs.hostPlatform.isLinux
        <| flip genAttrs (const "org.qbittorrent.qBittorrent.desktop") [
          "application/x-bittorrent"
          "x-scheme-handler/magnet"
        ];

      packages = [
        pkgs.qbittorrent
      ];

      xdg.config.files."qBittorrent/qBittorrent.${
        if osConfig.nixpkgs.hostPlatform.isDarwin then "ini" else "conf"
      }" =
        {
          generator = toINI { };
          value = {
            Meta.MigrationVersion = 8;
            LegalNotice.Accepted = true;

            Preferences."Advanced\\updateCheck" = false;

            BitTorrent."Session\\Port" = 7035;
          };
        };
    };
}
