{ lib, ... }: let
  lockedAs = Value: attrs: attrs // {
    inherit Value;
    Locked = true;
  };

  locked = attrs: attrs // { Locked = true; };

  _policies = {
    AutofillAddressEnabled    = false;
    AutofillCreditCardEnabled = false;

    DisableAppUpdate = true;
    AppAutoUpdate       = false;
    BackgroundAppUpdate = false;

    DisableFeedbackCommands = true;
    DisableFirefoxStudies   = true;
    DisablePocket           = true;
    DisableTelemetry        = true;
    DisableProfileImport    = true;
    DisableProfileRefresh   = true;

    BlockAboutConfig   = false;
    BlockAboutProfiles = true;
    BlockAboutSupport  = true;

    # We want it to be the default browser.
    DontCheckDefaultBrowser = false;

    NoDefaultBookmarks = true;

    # I accept the terms of use.
    SkipTermsOfUse = true;

    PictureInPicture = lockedAs false {};

    Homepage = locked { StartPage = "previous-session"; };

    EnableTrackingProtection = lockedAs true {
      Cryptomining   = true;
      EmailTracking  = true;
      Fingerprinting = true;
    };

    UserMessaging = locked {
      ExtensionRecommendations = false;
      FeatureRecommendations   = false;
      FirefoxLabs              = false;
      MoreFromMozilla          = false;
      SkipOnboarding           = true;
    };

    FirefoxSuggest = locked {
      ImproveSuggest       = false;
      SponsoredSuggestions = false;
      WebSuggestions       = false;
    };

    SearchEngines = {
      Default = "Kagi";

      PreventInstalls = true;

      Remove = [
        "Google"
        "Bing"
        "DuckDuckGo"
        "Wikipedia (en)"
      ];

      Add = [
        { Name = "Kagi";   Alias = "kk"; Method = "GET"; URLTemplate = "https://kagi.com/search?q={searchTerms}";      SuggestURLTemplate = "https://kagi.com/api/autosuggest?q={searchTerms}"; }
        { Name = "Google"; Alias = "gg"; Method = "GET"; URLTemplate = "https://google.com/search?q={searchTerms}";    SuggestURLTemplate = "https://google.com/complete/search?client=firefox&q={searchTerms}"; }
        { Name = "Yandex"; Alias = "yy"; Method = "GET"; URLTemplate = "https://yandex.com/search?text={searchTerms}"; SuggestURLTemplate = "https://suggest.yandex.com/suggest-ff.cgi?part={searchTerms}"; }

        { Name = "Wikipedia"; Alias = "ww"; Method = "GET"; URLTemplate = "https://en.wikipedia.org/w/index.php?title=Special:Search&search={searchTerms}"; }
        { Name = "YouTube"; Alias = "yt"; Method = "GET";   URLTemplate = "https://youtube.com/results?search_query={searchTerms}"; }

        { Name = "Sourcegraph"; Alias = "sg"; Method = "GET"; URLTemplate = "https://sourcegraph.com/search?q=context:global+{searchTerms}"; }
        { Name = "GitHub";      Alias = "gh"; Method = "GET"; URLTemplate = "https://github.com/search?type=repositories&q={searchTerms}"; }
        { Name = "Lib.rs";      Alias = "rs"; Method = "GET"; URLTemplate = "https://lib.rs/search?q={searchTerms}"; }

        { Name = "Seachix";               Alias = "sx"; Method = "GET"; URLTemplate = "https://searchix.ovh/?query={searchTerms}"; }
        { Name = "NixOS Packages";        Alias = "np"; Method = "GET"; URLTemplate = "https://search.nixos.org/packages?channel=unstable&sort=relevance&type=packages&query={searchTerms}"; }
        { Name = "NixOS Options";         Alias = "no"; Method = "GET"; URLTemplate = "https://search.nixos.org/options?channel=unstable&sort=relevance&type=options&query={searchTerms}"; }
        { Name = "Home Manager Options";  Alias = "ho"; Method = "GET"; URLTemplate = "https://home-manager-options.extranix.com/?release=master&query={searchTerms}"; }
        { Name = "Nix Darwin Options";    Alias = "do"; Method = "GET"; URLTemplate = "https://options.nix-darwin.uz/?release=master&query={searchTerms}"; }
      ];
    };
  };
in {
}
