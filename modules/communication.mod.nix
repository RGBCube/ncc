{
  flake.darwinModules.discord = {
    homebrew.casks = [ "vesktop" ];
  };

  flake.darwinModules.signal-desktop = {
    homebrew.casks = [ "signal" ];
  };

  flake.darwinModules.whatsapp = {
    homebrew.casks = [ "whatsapp" ];
  };

  flake.darwinModules.zulip = {
    homebrew.casks = [ "zulip" ];
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

  flake.homeModules.matrix =
    { pkgs, ... }:
    {
      packages = [ pkgs.cinny-desktop ];
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
      packages = optional osConfig.nixpkgs.hostPlatform.isLinux pkgs.signal-desktop;
    };

  flake.homeModules.thunderbird =
    { pkgs, ... }:
    {
      packages = [ pkgs.thunderbird ];
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
}
