{
  flake.darwinModules.keepassxc =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      homebrew.casks = singleton "keepassxc";
    };

  flake.homeModules.keepassxc =
    {
      osConfig,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.modules) mkIf;
      inherit (lib.trivial) const flip;
      inherit (lib.attrsets) genAttrs optionalAttrs;
      inherit (lib.generators) toINI;

      # TODO: Re-enable package override after upstream darwin YubiKey build is fixed.
      #
      # Also remove the config that disables update checking, as nixpkgs compiles that out.
      #
      # package = pkgs.keepassxc.override {
      #   withKeePassYubiKey = true;
      # };

      keepassConfig.generator = toINI { };
      keepassConfig.value = {
        Browser.Enabled = true;

        General.BackupBeforeSave = true;

        Messages.NoLegacyKeyFileWarning = true;

        General.UpdateCheckMessageShown = true;
        GUI.CheckForUpdates = false;
        GUI.CheckForUpdatesIncludeBetas = false;

        GUI.ToolButtonStyle = 4; # Follows platform style.

        Security.ClearSearch = true;
        Security.ClearSearchTimeout = 5; # 5 minutes.

        Security.LockDatabaseIdle = true;
        Security.LockDatabaseIdleSeconds = 3 * 60 * 60; # 3 hours.

        General.MinimizeAfterUnlock = true;
        Security.HideTotpPreviewPanel = true;

        SSHAgent.Enabled = true;
      }
      // optionalAttrs osConfig.nixpkgs.hostPlatform.isLinux {
        FdoSecrets.Enabled = true;
        FdoSecrets.ShowNotification = false;
        FdoSecrets.ConfirmDeleteItem = true;
        FdoSecrets.ConfirmAccessItem = true;
        FdoSecrets.UnlockBeforeSearch = true;
      };
    in
    {
      xdg.mime-apps.default-applications =
        mkIf osConfig.nixpkgs.hostPlatform.isLinux
        <| flip genAttrs (const "org.keepassxc.KeePassXC.desktop") [
          "application/x-keepass2"
        ];

      packages = mkIf osConfig.nixpkgs.hostPlatform.isLinux [
        pkgs.keepassxc
      ];

      files."Library/Application Support/KeePassXC/keepassxc.ini" =
        mkIf osConfig.nixpkgs.hostPlatform.isDarwin keepassConfig;

      xdg.config.files."keepassxc/keepassxc.ini" =
        mkIf osConfig.nixpkgs.hostPlatform.isLinux keepassConfig;
    };
}
