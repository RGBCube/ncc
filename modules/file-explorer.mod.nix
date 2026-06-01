{
  flake.darwinModules.file-explorer =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.modules) mkAfter;
      inherit (lib.shell) asShell;
    in
    {
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
      system.activationScripts.script.text = mkAfter ''
        ${config.system.activationScripts.unhide-library.text}
      '';
      system.activationScripts.unhide-library.text = asShell pkgs.nushell "unhide-library.nu" /* nu */ ''
        print "unhiding library..."
        ^/usr/bin/chflags nohidden r##'/Users/${config.system.primaryUser}/Library'##
      '';
    };

  flake.homeModules.file-explorer =
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
    in
    {
      xdg.mime-apps.default-applications =
        mkIf osConfig.nixpkgs.hostPlatform.isLinux
        <|
          flip genAttrs (const "org.kde.dolphin.desktop") [
            "inode/directory"
          ]
          // flip genAttrs (const "org.kde.ark.desktop") [
            # LIBARCHIVE (READ-WRITE)
            "application/x-tar"
            "application/x-compressed-tar"
            "application/x-bzip-compressed-tar"
            "application/x-bzip2-compressed-tar"
            "application/x-tarz"
            "application/x-xz-compressed-tar"
            "application/x-lzma-compressed-tar"
            "application/x-lzip-compressed-tar"
            "application/x-tzo"
            "application/x-lrzip-compressed-tar"
            "application/x-lz4-compressed-tar"
            "application/x-zstd-compressed-tar"
            "application/x-7z-compressed"

            # LIBARCHIVE (READ-ONLY)
            "application/x-deb"
            "application/x-cd-image"
            "application/x-bcpio"
            "application/x-cpio"
            "application/x-cpio-compressed"
            "application/x-sv4cpio"
            "application/x-sv4crc"
            "application/x-rpm"
            "application/x-compress"
            "application/gzip"
            "application/x-bzip"
            "application/x-bzip2"
            "application/x-lzma"
            "application/x-xz"
            "application/zlib"
            "application/zstd"
            "application/x-lz4"
            "application/x-lzip"
            "application/x-lrzip"
            "application/x-lzop"
            "application/x-source-rpm"
            "application/vnd.debian.binary-package"
            "application/vnd.efi.iso"
            "application/vnd.ms-cab-compressed"
            "application/x-xar"
            "application/x-iso9660-appimage"
            "application/x-archive"

            # ZIP
            "application/zip"
            "application/x-java-archive"

            # RAR
            "application/vnd.rar"

            # ARJ
            "application/x-arj"
            "application/arj"

            # UNARCHIVER
            "application/x-lha"
            "application/x-stuffit"
          ];

      packages = mkIf osConfig.nixpkgs.hostPlatform.isLinux [
        pkgs.kdePackages.dolphin
        pkgs.kdePackages.ark
      ];
    };
}
