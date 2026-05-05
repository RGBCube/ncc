{ inputs, lib, ... }:
let
  inherit (lib.attrsets)
    attrNames
    concatMapAttrs
    filterAttrs
    getAttr
    hasAttr
    mapAttrsToList
    optionalAttrs
    ;
  inherit (lib.lists)
    filter
    foldr
    singleton
    ;
  inherit (lib.trivial) const importJSON warn;
  inherit (lib.strings) hasInfix;

  extensions.consent-o-matic.id = "mdjildafknihdffpkfmmpnpoiajfjnjd";
  extensions.ublock-origin =
    let
      assets = importJSON "${inputs.ublock}/assets/assets.json";

      filterLists =
        (
          assets
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

      filters = [
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
    in
    {
      id = "blockjmkbacgjkknlgpkjjiijinjdanf";
      preinstalled = true;
      policy = {
        toOverwrite.filterLists =
          filter (name: !(hasInfix "://" name || name == "user-filters" || hasAttr name assets)) filterLists
          |> foldr (name: warn "helium: unknown ublock filter list: ${name}") filterLists;

        toOverwrite.filters = filters;

        userSettings = [
          [
            "userFiltersTrusted"
            "true"
          ]
        ];
      };
    };

  # YOUTUBE
  extensions.dearrow.id = "enamippconapkdmgfgjchkhakpfinmaj";
  extensions.sponsorblock.id = "mnjggcdmjocbbbhaepdhchncahnbgone";

  # VISUALS
  extensions.dark-reader.id = "eimadpbcbfnmbkopoojfekhnkhdbieeh";
  extensions.stylus.id = "clngdbkpkpeebahjckkjfobafhncgmne";
  extensions.refined-github.id = "hlepfoohegkhhmjieoechaddaejaokhf";

  # NAVIGATION
  extensions.violentmonkey.id = "jinjaccalgkegednnccohejagnlnfdag";
  extensions.vimium-c.id = "hfjbmagddngcpeloejdejnfgbamkjaeg";
  extensions.web-archives.id = "hkligngkgcpcolhcnkgccglchdafcnao";

  # SERVICES
  extensions.floccus.id = "fnaicdffflnofjppbagibeoednhnbjhg";
  extensions.kagi.id = "cdglnehniifkbagbbombnjghhcihifij";
  extensions.keepassxc-browser.id = "oboonakemofpalcgghocfoadofidjkkk";

  policy = {
    # EXTENSIONS
    ExtensionInstallBlocklist = singleton "*";

    ExtensionInstallAllowlist = policy.ExtensionInstallForcelist;
    ExtensionInstallForcelist =
      extensions
      |> filterAttrs (_: extension: !(extension.preinstalled or false))
      |> mapAttrsToList (const <| getAttr "id");

    ExtensionInstallSources = singleton "https://services.helium.imput.net/*";

    "3rdparty".extensions =
      extensions
      |> concatMapAttrs (
        _: extension: optionalAttrs (extension ? policy) { ${extension.id} = extension.policy; }
      );

    DefaultBrowserSettingEnabled = false;

    DeveloperToolsAvailability = 1;

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
      inherit (lib.attrsets) mapAttrsToList;
      inherit (lib.generators) toPlist;
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkAfter;
      inherit (lib.strings) toJSON;

      policyFiles = [
        {
          path = "/Library/Managed Preferences/net.imput.helium.plist";
          content = toPlist { escape = true; } policy;
        }
      ]
      ++ (
        policy."3rdparty".extensions
        |> mapAttrsToList (
          id: extensionPolicy: {
            path = "/Library/Managed Preferences/net.imput.helium.extensions.${id}.plist";
            content = toPlist { escape = true; } extensionPolicy;
          }
        )
      );
    in
    {
      system.activationScripts.script.text = mkAfter ''
        ${config.system.activationScripts.helium.text}
      '';
      system.activationScripts.helium.text = "${getExe pkgs.nushell} ${
        pkgs.writeText "helium-policy.nu" /* nu */ ''
          print "setting up helium policy..."

          mkdir `/Library/Managed Preferences`

          for entry in (r#'${toJSON policyFiles}'# | from json) {
            $entry.content | save --force $entry.path
            ^chown root:wheel $entry.path
            ^chmod 0644 $entry.path
          }

          (^sudo
            --user (ls --long /dev/console | get 0.user)
            ${getExe pkgs.defaultbrowser} helium)
        ''
      }";
    };

  flake.nixosModules.helium =
    { lib, ... }:
    let
      inherit (lib.strings) toJSON;
    in
    {
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
