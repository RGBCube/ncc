{
  flake.darwinModules.discord = {
    homebrew.casks = [ "vesktop" ];
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
      inherit (lib.lists) optional;
    in
    {
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
      allowedUnfreePackageNames = singleton "signal-desktop-bin"; # Signing bullshit.
    };

  flake.homeModules.signal-desktop =
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
      packages =
        optional osConfig.nixpkgs.hostPlatform.isLinux pkgs.signal-desktop
        ++ optional osConfig.nixpkgs.hostPlatform.isDarwin pkgs.signal-desktop-bin;
    };

  flake.darwinModules.whatsapp = {
    homebrew.casks = [ "whatsapp" ];
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

  flake.darwinModules.zulip = {
    homebrew.casks = [ "zulip" ];
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
    { pkgs, ... }:
    {
      packages = [ pkgs.thunderbird ];
    };
}
