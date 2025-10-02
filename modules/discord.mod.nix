{ config, lib, pkgs, ... }: let
  inherit (lib) merge mkIf;
in merge <| mkIf config.isDesktop {
  home-manager.sharedModules = [{
    xdg.configFile."Vencord/settings/quickCss.css".text = config.theme.discordCss;
  }];

  environment.systemPackages = mkIf config.isLinux [
    ((pkgs.discord.override {
      withOpenASAR = true;
      withVencord  = true;
    }).overrideAttrs (old: {
      nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.makeWrapper ];

      postFixup = ''
        wrapProgram $out/opt/Discord/Discord \
          --set ELECTRON_OZONE_PLATFORM_HINT "auto" \
          --add-flags "--enable-features=UseOzonePlatform --ozone-platform=wayland"
      '';
    }))
  ];
}
