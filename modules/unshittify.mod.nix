{
  flake.darwinModules.unshittify = {
    # LOGIN WINDOW
    system.defaults.loginwindow = {
      DisableConsoleAccess = true;
      GuestEnabled = false;
    };

    # SCREENSAVER PASSWORD
    system.defaults.CustomSystemPreferences."com.apple.screensaver" = {
      askForPassword = 1;
      askForPasswordDelay = 0;
    };

    # CLOUD SAVES
    system.defaults.NSGlobalDomain.NSDocumentSaveNewDocumentsToCloud = false;

    # QUARANTINE
    system.defaults.LaunchServices.LSQuarantine = false;

    # AUTO-UPDATE
    system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;

    # AD TRACKING
    system.defaults.CustomSystemPreferences."com.apple.AdLib" = {
      allowApplePersonalizedAdvertising = false;
      allowIdentifierForAdvertising = false;
      forceLimitAdTracking = true;
      personalizedAdsMigrated = false;
    };
  };
}
