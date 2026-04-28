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
      inherit (lib.attrsets) genAttrs;
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

        General.MinimizeAfterUnlock = true;
        General.BackupBeforeSave = true;

        GUI.CheckForUpdates = false;
        GUI.CheckForUpdatesIncludeBetas = false;

        GUI.ToolButtonStyle = 4; # Follows platform style.

        KeeShare.QuietSuccess = true;

        Security.ClearSearch = true;
        Security.ClearSearchTimeout = 5; # 5 minutes.

        Security.LockDatabaseIdle = true;
        Security.LockDatabaseIdleSeconds = 3 * 60 * 60; # 3 hours.

        Security.HideTotpPreviewPanel = true;

        # No Keeshare.
        KeeShare.Active = /* xml */ ''<?xml version="1.0"?><KeeShare><Active/></KeeShare>'';

        SSHAgent.Enabled = true;
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
