{ self, ... }:
{
  flake.homeModules.desktop = self.homeModules.keepassxc;
  flake.homeModules.keepassxc =
    {
      osConfig,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.modules) mkIf;
      inherit (lib.lists) singleton;
      inherit (lib.trivial) const flip;
      inherit (lib.attrsets) genAttrs optionalAttrs;
      inherit (lib.generators) toINI;

      keepassConfig.generator = toINI { };
      keepassConfig.value = {
        General.ConfigVersion = 2;

        General.BackupBeforeSave = true;

        General.UpdateCheckMessageShown = true;
        GUI.CheckForUpdates = false;
        GUI.CheckForUpdatesIncludeBetas = false;

        GUI.ToolButtonStyle = 4; # Follows platform style.
        Security.HideTotpPreviewPanel = true;

        Security.ClearSearch = true;
        Security.ClearSearchTimeout = 5; # 5 minutes.

        Security.LockDatabaseIdle = true;
        Security.LockDatabaseIdleSeconds = 3 * 60 * 60; # 3 hours.

        Browser.Enabled = true;
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

      packages = singleton pkgs.keepassxc;

      files."Library/Application Support/KeePassXC/keepassxc.ini" =
        mkIf osConfig.nixpkgs.hostPlatform.isDarwin keepassConfig;

      xdg.config.files."keepassxc/keepassxc.ini" =
        mkIf osConfig.nixpkgs.hostPlatform.isLinux keepassConfig;
    };
}
