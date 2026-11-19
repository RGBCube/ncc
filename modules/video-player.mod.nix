{ self, ... }:
{
  flake.darwinModules.desktop = self.darwinModules.video-player;
  flake.darwinModules.video-player = {
    system.defaults.CustomUserPreferences."com.colliderli.iina" = {
      SUEnableAutomaticChecks = false;
      SUAutomaticallyUpdate = false;
      SUSendProfileInfo = false;
    };
  };

  flake.homeModules.desktop = self.homeModules.video-player;
  flake.homeModules.video-player =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.modules) mkIf;
      inherit (lib.trivial) const flip;
      inherit (lib.attrsets) genAttrs getAttr;
    in
    {
      xdg.mime-apps.default-applications =
        mkIf osConfig.nixpkgs.hostPlatform.isLinux
        <| flip genAttrs (const "org.kde.haruna.desktop") [
          "audio/aac"
          "audio/ac3"
          "audio/flac"
          "audio/mp4"
          "audio/mpeg"
          "audio/ogg"
          "audio/vnd.wave"
          "audio/webm"
          "audio/x-matroska"
          "audio/x-mpegurl"
          "video/mp2t"
          "video/mp4"
          "video/mpeg"
          "video/ogg"
          "video/quicktime"
          "video/vnd.avi"
          "video/webm"
          "video/x-matroska"
          "video/x-ms-wmv"
        ];

      packages =
        singleton
        <| getAttr osConfig.nixpkgs.hostPlatform.parsed.kernel.name {
          darwin = pkgs.iina;
          linux = pkgs.haruna;
        };
    };
}
