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
      inherit (lib.lists) singleton;
      inherit (lib.modules) mkIf;
    in
    {
      packages =
        mkIf osConfig.nixpkgs.hostPlatform.isLinux
        <| singleton
        <|
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
            });

      xdg.config.files."Vencord/settings/quickCss.css".text = config.theme.discordCss;
    };
}
