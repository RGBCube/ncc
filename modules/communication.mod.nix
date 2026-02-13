{
  flake.darwinModules.communication = {
    homebrew.casks = [
      "signal"
      "vesktop"
      "whatsapp"
      "zulip"
    ];
  };

  flake.homeModules.communication =
    {
      osConfig,
      config,

      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) optionals;

      isLinux = osConfig.nixpkgs.hostPlatform.isLinux;
    in
    {
      packages = [
        pkgs.cinny-desktop
        pkgs.thunderbird
      ]
      ++ optionals isLinux [
        pkgs.signal-desktop
        (
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
        )
        pkgs.wasistlos
        pkgs.zulip
      ];

      xdg.config.files."Vencord/settings/quickCss.css".text = config.theme.discordCss;
    };
}
