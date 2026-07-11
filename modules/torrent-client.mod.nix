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
      inherit (lib.attrsets) genAttrs mapAttrsToList;
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

            GUI."Log\\Enabled" = true;

            Preferences."Advanced\\updateCheck" = false;
            Preferences."Search\\SearchEnabled" = true;

            BitTorrent."Session\\Port" = 7035;
          };
        };

      imports =
        {
          nyaasi = # py
            ''
              #VERSION: 1.0
              import xml.etree.ElementTree
              import helpers
              import novaprinter

              class nyaasi:
                NAMESPACE = "{https://nyaa.si/xmlns/nyaa}"

                url = "https://nyaa.si"
                name = "Nyaa.si"
                supported_categories = {
                  "all": "0_0",
                  "anime": "1_0",
                  "music": "2_0",
                  "books": "3_0",
                  "movies": "4_0",
                  "tv": "4_0",
                  "pictures": "5_0",
                  "software": "6_0",
                  "games": "6_2",
                }

                def search(self, what, category="all", /):
                  root = xml.etree.ElementTree.fromstring(helpers.retrieve_url(
                    f"{self.url}/?page=rss&q={what}&c={self.supported_categories[category]}&f=0"
                  ))

                  for item in root.iter("item"):
                    if not (link := item.findtext("link")): continue

                    novaprinter.prettyPrinter({
                      "engine_url": self.url,
                      "desc_link": item.findtext("guid", default=self.url),
                      "name": item.findtext("title", default=""),
                      "link": link,
                      "size": item.findtext(f"{self.NAMESPACE}size", default="-1"),
                      "seeds": item.findtext(f"{self.NAMESPACE}seeders", default="-1"),
                      "leech": item.findtext(f"{self.NAMESPACE}leechers", default="-1"),
                    })
            '';
        }
        |> mapAttrsToList (
          name: text:
          if osConfig.nixpkgs.hostPlatform.isDarwin then
            { files."Library/Application Support/qBittorrent/nova3/engines/${name}.py".text = text; }
          else
            { xdg.data.files."qBittorrent/nova3/engines/${name}.py".text = text; }
        );
    };
}
