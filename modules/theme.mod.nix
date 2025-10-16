let
  commonModule =
    { lib, pkgs, themes, ... }:
    let
      inherit (lib.modules) mkOption mkDefault;
      inherit (lib.types) attrs;
    in
    {
      options.theme = mkOption {
        type = attrs;
        description = "Theme configuration for the system";
        default = { };
      };

      config.theme = mkDefault (themes.custom (themes.raw.gruvbox-dark-hard // {
        cornerRadius = 4;
        borderWidth = 2;

        margin = 0;
        padding = 8;

        font.size.normal = 16;
        font.size.big = 20;

        font.sans.name = "Lexend";
        font.sans.package = pkgs.lexend;

        font.mono.name = "JetBrainsMono Nerd Font";
        font.mono.package = pkgs.nerd-fonts.jetbrains-mono;

        icons.name = "Gruvbox-Plus-Dark";
        icons.package = pkgs.gruvbox-plus-icons;
      }));
    };
in
{
  nixosModules.theme = commonModule;
  darwinModules.theme = commonModule;
  homeModules.theme = commonModule;
}