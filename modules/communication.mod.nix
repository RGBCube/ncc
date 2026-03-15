{
  flake.darwinModules.discord =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      homebrew.casks = singleton "vesktop";
    };

  flake.homeModules.discord =
    {
      osConfig,
      config,

      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.modules) mkIf;
      inherit (lib.trivial) const flip;
      inherit (lib.attrsets) genAttrs;
      inherit (lib.lists) optional;
    in
    {
      xdg.mime-apps.default-applications =
        mkIf osConfig.nixpkgs.hostPlatform.isLinux
        <| flip genAttrs (const "discord.desktop") [
          "x-scheme-handler/discord"
        ];

      packages = optional osConfig.nixpkgs.hostPlatform.isLinux (
        (pkgs.discord.override {
          withOpenASAR = true;
          withVencord = true;
        }).overrideAttrs
          (old: {
            nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.makeWrapper ];

            postFixup = ''
              wrapProgram $out/opt/Discord/Discord \
                --set ELECTRON_OZONE_PLATFORM_HINT "auto" \
                --add-flags "--enable-features=UseOzonePlatform --ozone-platform=wayland"
            '';
          })
      );

      xdg.config.files."Vencord/settings/quickCss.css".text = config.theme.discordCss;
    };

  flake.darwinModules.signal-desktop =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      homebrew.casks = singleton "signal";
    };

  flake.homeModules.signal-desktop =
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
      inherit (lib.lists) optional;
    in
    {
      xdg.mime-apps.default-applications =
        mkIf osConfig.nixpkgs.hostPlatform.isLinux
        <| flip genAttrs (const "signal.desktop") [
          "x-scheme-handler/sgnl"
          "x-scheme-handler/signalcaptcha"
        ];

      packages = optional osConfig.nixpkgs.hostPlatform.isLinux pkgs.signal-desktop;
    };

  flake.darwinModules.whatsapp =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      homebrew.casks = singleton "whatsapp";
    };

  flake.homeModules.whatsapp =
    {
      osConfig,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) optional;
    in
    {
      packages = optional osConfig.nixpkgs.hostPlatform.isLinux pkgs.wasistlos;
    };

  flake.darwinModules.zulip =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      homebrew.casks = singleton "zulip";
    };

  flake.homeModules.zulip =
    {
      osConfig,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) optional;
    in
    {
      packages = optional osConfig.nixpkgs.hostPlatform.isLinux pkgs.zulip;
    };

  flake.homeModules.cinny =
    { pkgs, ... }:
    {
      packages = [ pkgs.cinny-desktop ];
    };

  flake.homeModules.thunderbird =
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
        <| flip genAttrs (const "thunderbird.desktop") [
          "message/rfc822"
          "x-scheme-handler/mailto"
          "text/calendar"
          "text/x-vcard"
        ];

      packages = [ pkgs.thunderbird ];
    };
}
