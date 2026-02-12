{
  flake.darwinModules.file-explorer = {
    system.defaults.NSGlobalDomain = {
      AppleShowAllFiles = true;
      AppleShowAllExtensions = true;

      "com.apple.springing.enabled" = true;
      "com.apple.springing.delay" = 0.0;
    };

    system.defaults.CustomSystemPreferences."com.apple.desktopservices" = {
      DSDontWriteNetworkStores = true;
      DSDontWriteUSBStores = true;
    };

    system.defaults.finder = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;

      FXEnableExtensionChangeWarning = true;
      FXPreferredViewStyle = "Nlsv";
      FXRemoveOldTrashItems = true;

      _FXShowPosixPathInTitle = true;
      _FXSortFoldersFirst = true;
      _FXSortFoldersFirstOnDesktop = false;

      NewWindowTarget = "Home";

      QuitMenuItem = true;

      ShowExternalHardDrivesOnDesktop = true;
      ShowMountedServersOnDesktop = true;
      ShowPathbar = true;
      ShowRemovableMediaOnDesktop = true;
      ShowStatusBar = true;
    };

    system.defaults.CustomSystemPreferences."com.apple.finder" = {
      DisableAllAnimations = true;

      FXArrangeGroupViewBy = "Name";
      FxDefaultSearchScope = "SCcf";

      WarnOnEmptyTrash = false;
    };

    # Unhide ~/Library.
    system.activationScripts.postActivation.text = /* bash */ ''
      /usr/bin/chflags nohidden ~/Library
    '';
  };

  flake.nixosModules.file-explorer =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.kdePackages.dolphin
        pkgs.kdePackages.ark
      ];
    };
}
