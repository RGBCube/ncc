{
  self,
  inputs,
  lib,
  ...
}:
let
  inherit (lib.attrsets)
    attrNames
    concatMapAttrs
    filterAttrs
    getAttr
    hasAttr
    mapAttrs'
    mapAttrsToList
    nameValuePair
    optionalAttrs
    ;
  inherit (lib.lists)
    elemAt
    filter
    foldr
    head
    isList
    singleton
    ;
  inherit (lib.trivial)
    const
    importJSON
    warn
    flip
    ;
  inherit (lib.fixedPoints) fix;
  inherit (lib.strings)
    concatStrings
    concatStringsSep
    hasInfix
    isString
    match
    split
    splitString
    ;

  # UNSLOP
  extensions.consent-o-matic.id = "mdjildafknihdffpkfmmpnpoiajfjnjd";
  extensions.ublock-origin =
    let
      assets = importJSON "${inputs.ublock}/assets/assets.json";

      filterLists =
        (
          assets
          |> filterAttrs (_: spec: (spec.content or null) == "filters" && (spec.group or null) != "regions")
          |> flip removeAttrs [
            "ublock-experimental"
          ]
          |> attrNames
        )
        ++ [
          "TUR-0"
          "user-filters"

          "https://raw.githubusercontent.com/DandelionSprout/adfilt/refs/heads/master/BrowseWebsitesWithoutLoggingIn.txt"
          "https://raw.githubusercontent.com/DandelionSprout/adfilt/refs/heads/master/ClearURLs%20for%20uBo/clear_urls_uboified.txt"
          "https://raw.githubusercontent.com/DandelionSprout/adfilt/refs/heads/master/LegitimateURLShortener.txt"
          "https://raw.githubusercontent.com/yokoffing/filterlists/refs/heads/main/annoyance_list.txt"
          "https://raw.githubusercontent.com/yokoffing/filterlists/refs/heads/main/click2load.txt"
          "https://raw.githubusercontent.com/yokoffing/filterlists/refs/heads/main/privacy_essentials.txt"
        ];

      mkStylesheet =
        hostname: css:
        let
          normalize =
            string:
            split "[[:space:]]+" string |> filter (part: isString part && part != "") |> concatStringsSep " ";
        in
        split ''/\*([^*]|\*+[^*/])*\*+/'' css
        |> filter isString
        |> concatStrings
        |> split ''([^{}]+)\{([^{}]*)\}''
        |> filter isList
        |> map (
          rule:
          let
            selector = normalize (head rule);

            declarations =
              elemAt rule 1
              |> splitString ";"
              |> map normalize
              |> filter (declaration: declaration != "")
              |> map (
                declaration:
                if match ".*![[:space:]]*important" declaration == null then
                  "${declaration} !important"
                else
                  declaration
              );
          in
          if declarations == singleton "display: none !important" then
            "${hostname}##${selector}"
          else
            "${hostname}##${selector}:style(${concatStringsSep "; " declarations})"
        );
    in
    {
      id = "blockjmkbacgjkknlgpkjjiijinjdanf";
      preinstalled = true;

      settings.toolbar_pin = "force_pinned";

      policy.userSettings = singleton [
        "userFiltersTrusted"
        "true"
      ];

      policy.toOverwrite.filterLists =
        filter (name: !(hasInfix "://" name || name == "user-filters" || hasAttr name assets)) filterLists
        |> foldr (name: warn "helium: unknown ublock filter list: ${name}") filterLists;

      policy.toOverwrite.filters = [
        "dolap.com##.fancybox-wrap"
      ]
      # YOUTUBE
      ++ [
        # SHORTS -> WATCH
        ''||youtube.com/shorts/$document,uritransform=/^https:\/\/(?:www\.|m\.)?youtube\.com\/shorts\/([^\/?#]+)/https:\/\/www.youtube.com\/watch?v=\$1/''

        # TODO: Allow youtube embeds without click2load'ing, as they are broken: https://github.com/uBlockOrigin/uBlock-issues/issues/3868
        "@@||youtube.com/embed/$frame"
        "@@||youtube-nocookie.com/embed/$frame"
      ]
      # OLD REDDIT
      ++ [
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
      ]
      # MAKE X ANONYMOUS: https://gist.github.com/sin-ack/5a6f7e34e78b6acf971d95808c9331d3
      ++ mkStylesheet "x.com" /* css */ ''
        /* user avatars */
        [data-testid=tweet] .r-1mrc8m9.r-1awozwy {
          display: none;
        }

        [data-testid^="UserAvatar-Container-"] {
          display: none;
        }

        /* don't hide avatars on profile pages */
        a[href$="header_photo"] + div [data-testid^="UserAvatar-Container-"] {
          display: block;
        }

        /* Original username */
        [data-testid="User-Name"] > :nth-child(1) [dir=ltr],
        [data-testid="notification"] > :nth-child(1) [dir=ltr] a {
          display: none;
        }

        /* Anonymous username */
        [data-testid="User-Name"]::before,
        [data-testid="notification"] > :nth-child(1) span[dir=ltr]::before {
          content: "Anonymous";
          opacity: 1;
          font-weight: bold;
          font-family: "TwitterChirp";
        }

        [data-testid="User-Name"]:hover::before {
          text-decoration: underline;
        }

        /* @handle */
        [data-testid="User-Name"] > :nth-child(2) [tabindex="-1"] {
          display: none;
        }

        /* "Replying to" message in tweet box */
        .r-gu64tb button > span {
          font-size: 0;
        }

        .r-136ojw6.r-1wbh5a2 button::after {
          font-size: inherit;
          content: "Anonymous";
          color: inherit;
        }

        /* "Replying to" in tweets and notifs */

        [id^="id__"][dir=ltr] a[dir=ltr] {
          font-size: 0;
        }

        [id^="id__"][dir=ltr] a[dir=ltr]::after {
          font-size: 1rem;
          content: "Anonymous";
          color: inherit;
        }
      '';
    };

  # YOUTUBE
  extensions.dearrow.id = "enamippconapkdmgfgjchkhakpfinmaj";
  extensions.sponsorblock.id = "mnjggcdmjocbbbhaepdhchncahnbgone";

  # VISUALS
  extensions.dark-reader.id = "eimadpbcbfnmbkopoojfekhnkhdbieeh";
  extensions.refined-github.id = "hlepfoohegkhhmjieoechaddaejaokhf";

  # NAVIGATION
  extensions.violentmonkey = {
    id = "jinjaccalgkegednnccohejagnlnfdag";

    preferences.user_scripts_enabled = true;
  };
  extensions.vimium-c.id = "hfjbmagddngcpeloejdejnfgbamkjaeg";

  # SERVICES
  extensions.kagi.id = "cdglnehniifkbagbbombnjghhcihifij";
  extensions.keepassxc-browser = {
    id = "oboonakemofpalcgghocfoadofidjkkk";

    settings.toolbar_pin = "force_pinned";

    policy.settings = fix (settings: {
      autoFillRelevantCredential = true;

      defaultGroup = "Web";
      defaultPasskeyGroup = settings.defaultGroup;

      downloadFaviconAfterSave = true;
      passkeys = true;

      useCompactMode = true;
      useMonochromeToolbarIcon = true;
      usePasswordGeneratorIcons = true;
    });
  };

  policy = {
    # EXTENSIONS
    ExtensionInstallBlocklist = singleton "*";

    ExtensionInstallAllowlist = policy.ExtensionInstallForcelist;
    ExtensionInstallForcelist =
      extensions
      |> filterAttrs (_: extension: !(extension.preinstalled or false))
      |> mapAttrsToList (const <| getAttr "id");

    ExtensionInstallSources = singleton "https://services.helium.imput.net/*";

    ExtensionSettings =
      extensions
      |> concatMapAttrs (
        _: extension: optionalAttrs (extension ? settings) { ${extension.id} = extension.settings; }
      );

    "3rdparty".extensions =
      extensions
      |> concatMapAttrs (
        _: extension: optionalAttrs (extension ? policy) { ${extension.id} = extension.policy; }
      );

    # MISC
    DefaultBrowserSettingEnabled = false;

    DeveloperToolsAvailability = 1;

    BatterySaverModeAvailability = 0;

    # "Continue where you left off" can't be set declaratively on a consumer machine:
    # - Preference `session.restore_on_startup` is HMAC-tracked, writing it externally trips Chromium's reset popup.
    # - Policy `RestoreOnStartup` is restricted by upstream Chromium to AD-joined / Cloud-Management-enrolled
    #   devices only (anti-hijack mitigation), so the managed plist value is loaded then ignored.
    #
    # TODO: Remove this comment when Helium on MacOS gets a toggle to disable these checks with an environment variable.
    RestoreOnStartup = 1;

    # BOOKMARKS
    ManagedBookmarks =
      let
        mkFolder = name: children: { inherit name children; };

        mkBookmark = name: url: { inherit name url; };

        mkScriptlet =
          name: javascript:
          mkBookmark name (
            "javascript:"
            + "{${javascript}}"
            + /* javascript */ ''
              void undefined;
            ''
          );
      in
      [
        { toplevel_name = "Tools"; }

        (mkFolder "Archive" [
          (mkFolder "Wayback" [
            (mkScriptlet "View" /* javascript */ ''
              window.open("https://web.archive.org/web/*/" + location.href);
            '')
            (mkScriptlet "Save" /* javascript */ ''
              window.open("https://web.archive.org/save/" + location.href);
            '')
          ])
          (mkFolder "Archive.is" [
            (mkScriptlet "View" /* javascript */ ''
              window.open("https://archive.ph/newest/" + location.href);
            '')
            (mkScriptlet "Save" /* javascript */ ''
              window.open("https://archive.ph/?run=1&url=" + encodeURIComponent(location.href));
            '')
          ])
        ])

        (mkFolder "Reverse Image" (
          let
            mkReverse =
              name: prefix:
              mkScriptlet name /* javascript */ ''
                document.addEventListener("click", function handler(event) {
                  let image = event.target.closest("img");
                  if (!image) return;

                  event.preventDefault();
                  event.stopPropagation();
                  document.removeEventListener("click", handler, true);

                  window.open("${prefix}" + encodeURIComponent(image.src));
                }, true);
              '';
          in
          [
            (mkReverse "Yandex" "https://yandex.com/images/search?rpt=imageview&url=")
            (mkReverse "Google Lens" "https://lens.google.com/uploadbyurl?url=")
            (mkReverse "Bing" "https://www.bing.com/images/search?view=detailv2&iss=sbi&q=imgurl:")
            (mkReverse "TinEye" "https://www.tineye.com/search?url=")
          ]
        ))

        (mkFolder "Nuke" [
          (mkScriptlet "Sticky Elements" /* javascript */ ''
            document.querySelectorAll("body *").forEach((element) => {
              let position = getComputedStyle(element).position;
              if (position === "fixed" || position === "sticky") element.parentNode.removeChild(element);
            });

            document.documentElement.style.overflow = "auto";
            document.body.style.overflow = "auto";
          '')

          (mkScriptlet "Copy Paste Restrictions" /* javascript */ ''
            ["copy", "cut", "paste", "selectstart", "contextmenu", "dragstart"].forEach((eventName) => {
              document.addEventListener(eventName, (event) => event.stopPropagation(), true);
            });

            document.querySelectorAll("*").forEach((element) => {
              element.style.userSelect = "auto";
              element.style.webkitUserSelect = "auto";
            });
          '')
        ])

        (mkFolder "Toggle" (
          let
            mkIndication = text: /* javascript */ ''
              let indication = document.body.appendChild(document.createElement("div"));
              indication.textContent = ${text};

              Object.assign(indication.style, {
                position: "fixed",
                top: "0",
                left: "0",

                zIndex: "calc(infinity)",

                padding: "8px 16px",
                borderRadius: "8px",

                colorScheme: "light dark",
                background: "Canvas",
                color: "CanvasText",
                font: "14px/1 system-ui",

                pointerEvents: "none",
              });

              indication.animate(
                [
                  { opacity: 1, offset: 0.6, easing: "cubic-bezier(0.4, 0, 0.2, 1)" },
                  { opacity: 0, offset: 1 },
                ],
                { duration: 1500, fill: "forwards" },
              )
              .finished
              .then(() => indication.remove());
            '';
          in
          [
            (mkScriptlet "Password Inputs" /* javascript */ ''
              let shown = false;

              document.querySelectorAll("input").forEach((input) => {
                if (input.type === "password") {
                  input.dataset.wasPassword = "";
                  input.type = "text";
                  shown = true;
                } else if ("wasPassword" in input.dataset) {
                  delete input.dataset.wasPassword;
                  input.type = "password";
                }
              });

              ${mkIndication /* js */ ''"Passwords " + (shown ? "shown" : "hidden")''}
            '')

            (mkScriptlet "Design Mode" /* javascript */ ''
              document.designMode = document.designMode === "on" ? "off" : "on";

              ${mkIndication /* js */ ''"Design mode " + document.designMode''}
            '')

            (mkScriptlet "Selections" /* javascript */ ''
              let enabler = (window.__forceSelection ??= Object.assign(document.createElement("style"), {
                textContent: `
                  *, *::before, *::after { user-select: text !important; }
                  [data-force-selection-before]::before { content: none !important; }
                  [data-force-selection-after]::after { content: none !important; }
                `,
                stop: (event) => event.stopPropagation(),
              }));

              if (!enabler.isConnected) {
                document.head.appendChild(enabler);

                ["copy", "cut", "paste", "selectstart", "contextmenu", "dragstart"].forEach((eventName) => {
                  document.addEventListener(eventName, enabler.stop, true);
                });

                /* Generated content (::before/::after) is unselectable,
                   so replace it with real text nodes and suppress the originals. */
                document.querySelectorAll("*").forEach((element) => {
                  [
                    ["::before", "data-force-selection-before", "afterbegin"],
                    ["::after", "data-force-selection-after", "beforeend"],
                  ].forEach(([pseudo, attribute, position]) => {
                    let content = getComputedStyle(element, pseudo).content.match(/^"(.*)"$/s)?.[1];
                    if (content == null) return;

                    element.setAttribute(attribute, "");
                    element.insertAdjacentElement(position, Object.assign(document.createElement("span"), {
                      className: "force-selection-pseudo",
                      textContent: content,
                    }));
                  });
                });
              } else {
                enabler.remove();

                ["copy", "cut", "paste", "selectstart", "contextmenu", "dragstart"].forEach((eventName) => {
                  document.removeEventListener(eventName, enabler.stop, true);
                });

                document.querySelectorAll(".force-selection-pseudo").forEach((span) => span.remove());
                document.querySelectorAll("[data-force-selection-before], [data-force-selection-after]").forEach((element) => {
                  element.removeAttribute("data-force-selection-before");
                  element.removeAttribute("data-force-selection-after");
                });
              }

              ${mkIndication /* js */ ''"Selections " + (enabler.isConnected ? "enabled" : "disabled")''}
            '')
          ]
        ))
      ];

    # SEARCH
    DefaultSearchProviderEnabled = true;
    DefaultSearchProviderName = "Kagi";
    DefaultSearchProviderSearchURL = "https://kagi.com/search?q={searchTerms}";
    DefaultSearchProviderSuggestURL = "https://kagi.com/api/autosuggest?q={searchTerms}";
    SearchSuggestEnabled = true;
  };

  preferences = {
    helium.completed_onboarding = true;
    helium.services.user_consented = true;

    helium.browser.layout = 2; # Vertical.
    helium.browser.rounded_frame = false;

    helium.browser.new_tab_next_to_active = true;

    bookmark_bar.show_on_all_tabs = true;
    bookmark_bar.show_tab_groups = false;

    download.prompt_for_download = true; # Ask where to save each time.

    # `extensions.settings` is HMAC-tracked. Writing it externally trips Chromium's reset popup warning.
    # Toggle it all manually in helium://extensions for now.
    # extensions.settings =
    #   extensions
    #   |> mapAttrs' (
    #     _: extension: nameValuePair extension.id ({ incognito = true; } // extension.preferences or { })
    #   );
  };
in
{
  flake.darwinModules.desktop = self.darwinModules.helium;
  flake.darwinModules.helium =
    {
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) concatMapAttrs;
      inherit (lib.generators) toPlist;
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe;
    in
    {
      system.services.helium-policy = {
        imports = singleton self.modularServices.managed-files;

        managed-files = {
          inherit (pkgs) smfh nushell;

          files = {
            "/Library/Managed Preferences/net.imput.helium.plist".text = policy |> toPlist { escape = true; };
          }
          // (
            policy."3rdparty".extensions
            |> concatMapAttrs (
              id: extensionPolicy: {
                "/Library/Managed Preferences/net.imput.helium.extensions.${id}.plist".text =
                  extensionPolicy |> toPlist { escape = true; };
              }
            )
          );
        };
      };

      system.activationScripts.postActivation.text = "${pkgs.writers.writeNu "helium-default-browser.nu"
        /* nu */ ''
          (^/usr/bin/sudo
            --set-home
            --user (ls --long /dev/console | get 0.user)
            ${getExe pkgs.defaultbrowser} helium)
        ''
      }";
    };

  flake.nixosModules.desktop = self.nixosModules.helium;
  flake.nixosModules.helium =
    { lib, ... }:
    let
      inherit (lib.strings) toJSON;
    in
    {
      environment.etc."chromium/policies/managed/policies.json".text = toJSON policy;
    };

  flake.homeModules.desktop = self.homeModules.helium;
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
      inherit (lib.strings) toJSON;

      defaultPreferences.type = "copy";
      defaultPreferences.text = toJSON preferences;
    in
    {
      files."Library/Application Support/net.imput.helium/Default/Preferences" =
        mkIf osConfig.nixpkgs.hostPlatform.isDarwin defaultPreferences;
      xdg.config.files."helium/Default/Preferences" =
        mkIf osConfig.nixpkgs.hostPlatform.isLinux defaultPreferences;

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
