{ lib, ... }: let
  inherit (lib) enabled merge;

  lockedAs = Value: merge {
    inherit Value;
    Locked = true;
  };

  locked = merge { Locked = true; };
in {
  home-manager.sharedModules = [{
    programs.zen-browser = enabled {
      # package = mkIf config.isDarwin null;

      policies = {
        AutofillAddressEnabled    = false;
        AutofillCreditCardEnabled = false;

        DisableAppUpdate        = true;
        DisableFeedbackCommands = true;
        DisableFirefoxStudies   = true;
        DisablePocket           = true;
        DisableTelemetry        = true;

        # We want Zen to be the default browser.
        DontCheckDefaultBrowser = false;

        NoDefaultBookmarks = true;

        # I accept the terms of use.
        SkipTermsOfUse = true;

        PictureInPicture = lockedAs false;

        Homepage.StartPage = "previous-session";

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
      };

      # policies.Preferences = {
        
      # };
    };
  }];
}
