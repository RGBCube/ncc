let
  commonModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) singleton;
    in
    {
      home.extraModules = singleton {
        xdg.config.files."Vencord/settings/quickCss.css".text = config.theme.discordCss;
      };

      environment.systemPackages = singleton (
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
    };
in
{
  nixosModules.discord = commonModule;
  darwinModules.discord = commonModule;
}
