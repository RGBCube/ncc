{ inputs, lib, ... }:
let
  inherit (lib) fix;
  inherit (lib.attrsets)
    attrNames
    filterAttrs
    getAttr
    hasAttr
    mapAttrsToList
    ;
  inherit (lib.lists)
    filter
    singleton
    ;
  inherit (lib.trivial) const importJSON;
  inherit (lib.strings) hasInfix;

  extensions = {
    consent-o-matic.id = "mdjildafknihdffpkfmmpnpoiajfjnjd";
    ublock-origin = fix (self: {
      id = "blockjmkbacgjkknlgpkjjiijinjdanf";
      preinstalled = true;

      filters.assets = importJSON "${inputs.ublock}/assets/assets.json";

      filters.wanted =
        (
          self.filters.assets
          |> filterAttrs (_: spec: (spec.content or null) == "filters" && (spec.group or null) != "regions")
          |> attrNames
          |> filter (name: name != "ublock-experimental")
        )
        ++ [
          "TUR-0"
          "user-filters"

          "https://raw.githubusercontent.com/DandelionSprout/adfilt/refs/heads/master/ClearURLs%20for%20uBo/clear_urls_uboified.txt"
          "https://raw.githubusercontent.com/yokoffing/filterlists/refs/heads/main/privacy_essentials.txt"
          "https://raw.githubusercontent.com/DandelionSprout/adfilt/refs/heads/master/LegitimateURLShortener.txt"
          "https://raw.githubusercontent.com/yokoffing/filterlists/refs/heads/main/annoyance_list.txt"
          "https://raw.githubusercontent.com/DandelionSprout/adfilt/refs/heads/master/BrowseWebsitesWithoutLoggingIn.txt"
        ];

      filters.warnings =
        self.filters.wanted
        |> filter (
          name: !(hasInfix "://" name || name == "user-filters" || hasAttr name self.filters.assets)
        )
        |> map (invalid: "helium: unknown ublock filter list: ${invalid}");

      filters.user = [
        "@@||reddit.com/media$document"
        "@@||reddit.com/mod$document"
        "@@||reddit.com/poll$document"
        "@@||reddit.com/settings$document"
        "@@||reddit.com/topics$document"
        "@@||reddit.com/community-points$document"
        "@@||reddit.com/appeal$document"
        "@@||reddit.com/appeals$document"
        "@@||reddit.com/notifications$document"
        "@@||reddit.com/message/compose/$document"
        "@@||reddit.com/mail^$document"
        "@@||reddit.com/answers^$document"
        "@@||reddit.com/r/subreddit^$document"
        ''@@/^https:\/\/\w*\.?reddit\.com\/r\/[A-Za-z0-9_]+\/s\//$document''
        ''@@/^https:\/\/\w*\.?reddit\.com\/.*[?&]new_reddit=true(?:$|[&#])/$document''

        ''||reddit.com/gallery/$document,uritransform=/^https:\/\/(?:www\.|np\.|amp\.|i\.)?reddit\.com\/gallery\/(.*)/https:\/\/old.reddit.com\/comments\/\$1/''
        ''||reddit.com^$document,uritransform=/^https:\/\/(?:www\.|np\.|amp\.|i\.)?reddit\.com\/(?!gallery\/)/https:\/\/old.reddit.com\//''

        "old.reddit.com##:is(#eu-cookie-policy, #redesign-beta-optin-btn)"
      ];
    });

    # YOUTUBE
    dearrow.id = "enamippconapkdmgfgjchkhakpfinmaj";
    sponsorblock.id = "mnjggcdmjocbbbhaepdhchncahnbgone";

    # VISUALS
    dark-reader.id = "eimadpbcbfnmbkopoojfekhnkhdbieeh";
    stylus.id = "clngdbkpkpeebahjckkjfobafhncgmne";
    refined-github.id = "hlepfoohegkhhmjieoechaddaejaokhf";

    # NAVIGATION
    violentmonkey.id = "jinjaccalgkegednnccohejagnlnfdag";
    vimium-c.id = "hfjbmagddngcpeloejdejnfgbamkjaeg";
    web-archives.id = "hkligngkgcpcolhcnkgccglchdafcnao";

    # SERVICES
    floccus.id = "fnaicdffflnofjppbagibeoednhnbjhg";
    kagi.id = "cdglnehniifkbagbbombnjghhcihifij";
  };

  policy =
    let
      installableIds =
        extensions
        |> filterAttrs (_: extension: !(extension.preinstalled or false))
        |> mapAttrsToList (const <| getAttr "id");
    in
    {
      # EXTENSIONS
      ExtensionInstallForcelist = installableIds;
      ExtensionInstallAllowlist = installableIds;
      ExtensionInstallSources = singleton "https://services.helium.imput.net/*";

      # UBLOCK ORIGIN
      "3rdparty".extensions.${extensions.ublock-origin.id} = {
        toOverwrite.filterLists = extensions.ublock-origin.filters.wanted;
        toOverwrite.filters = extensions.ublock-origin.filters.user;
        userSettings = [
          [
            "userFiltersTrusted"
            "true"
          ]
        ];
      };

      DefaultBrowserSettingEnabled = false;

      # SEARCH
      DefaultSearchProviderEnabled = true;
      DefaultSearchProviderName = "Kagi";
      DefaultSearchProviderSearchURL = "https://kagi.com/search?q={searchTerms}";
      DefaultSearchProviderSuggestURL = "https://kagi.com/api/autosuggest?q={searchTerms}";
      SearchSuggestEnabled = true;
    };
in
{
  flake.darwinModules.helium =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.generators) toPlist;
      inherit (lib.modules) mkAfter;

      managedPolicyPlist = toPlist { escape = true; } policy;
    in
    {
      inherit (extensions.ublock-origin.filters) warnings;

      system.activationScripts.script.text = mkAfter ''
        ${config.system.activationScripts.helium.text}
      '';
      system.activationScripts.helium.text = /* bash */ ''
        # TODO: Rewrite in nu.
        echo "setting up helium policy..."
        /usr/bin/install -d -m 755 "/Library/Managed Preferences"
        /bin/cat > "/Library/Managed Preferences/net.imput.helium.plist" <<'PLIST_EOF'
        ${managedPolicyPlist}
        PLIST_EOF
        /usr/sbin/chown root:wheel "/Library/Managed Preferences/net.imput.helium.plist"
        /bin/chmod 0644 "/Library/Managed Preferences/net.imput.helium.plist"

        console_user=$(/usr/bin/stat -f%Su /dev/console)
        /usr/bin/sudo -u "$console_user" ${pkgs.defaultbrowser}/bin/defaultbrowser helium
      '';
    };

  flake.nixosModules.helium =
    { lib, ... }:
    let
      inherit (lib.strings) toJSON;
    in
    {
      inherit (extensions.ublock-origin.filters) warnings;

      environment.etc."chromium/policies/managed/policies.json".text = toJSON policy;
    };

  flake.homeModules.helium =
    {
      lib,
      osConfig,
      ...
    }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.modules) mkIf;
      inherit (lib.trivial) const flip;
      inherit (lib.attrsets) genAttrs;
    in
    {
      inherit (extensions.ublock-origin.filters) warnings;

      xdg.mime-apps.default-applications =
        mkIf osConfig.nixpkgs.hostPlatform.isLinux
        <| flip genAttrs (const "helium.desktop") [
          "application/pdf"
          "application/rdf+xml"
          "application/rss+xml"
          "application/xhtml+xml"
          "application/xhtml_xml"
          "application/xml"
          "image/gif"
          "image/jpeg"
          "image/png"
          "image/webp"
          "text/html"
          "text/xml"
          "x-scheme-handler/http"
          "x-scheme-handler/https"
        ];

      packages = singleton inputs.helium.packages.${osConfig.nixpkgs.hostPlatform.system}.default;
    };
}
