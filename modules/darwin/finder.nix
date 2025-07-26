{
  system.defaults.NSGlobalDomain = {
    AppleShowAllFiles = true;
    AppleShowAllExtensions = true;

    "com.apple.springing.enabled" = true;
    "com.apple.springing.delay"   = 0.0;
  };

  system.defaults.CustomSystemPreferences."com.apple.desktopservices" = {
    DSDontWriteNetworkStores = true;
    DSDontWriteUSBStores     = true;
  };

  system.defaults.finder = {
    AppleShowAllExtensions = true;
    AppleShowAllFiles      = true;

    FXEnableExtensionChangeWarning = true;
    FXPreferredViewStyle           = "Nlsv"; # List style.
    FXRemoveOldTrashItems          = true;

    _FXShowPosixPathInTitle      = true;
    _FXSortFoldersFirst          = true;
    _FXSortFoldersFirstOnDesktop = false;

    NewWindowTarget = "Home";

    QuitMenuItem = true; # Allow quitting of Finder application

    ShowExternalHardDrivesOnDesktop = true;
    ShowMountedServersOnDesktop     = true;
    ShowPathbar                     = true;
    ShowRemovableMediaOnDesktop     = true;
    ShowStatusBar                   = true;
  };

  system.defaults.CustomSystemPreferences."com.apple.finder" = {
    DisableAllAnimations = true;

    FXArrangeGroupViewBy = "Name";
    FxDefaultSearchScope = "SCcf"; # Search in current folder by default.

    WarnOnEmptyTrash = false;
  };

  home-manager.sharedModules = [(homeArgs: let
    lib' = homeArgs.lib;

    inherit (lib'.hm.dag) entryAfter;
  in {
    home.activation.showLibrary = entryAfter [ "writeBoundary" ] /* bash */ ''
      # Unhide ~/Library.
      /usr/bin/chflags nohidden ~/Library
    '';
  })];
}
