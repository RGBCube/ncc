{ self, inputs, ... }:
{
  flake.commonModules.theme =
    { lib, pkgs, ... }:
    let
      inherit (lib.modules) mkDefault;
      inherit (lib.options) mkOption;
      inherit (lib.types) attrs;
    in
    {
      options.theme = mkOption {
        type = attrs;
        description = "Theme configuration for the system";
        default = { };
      };

      config.theme =
        mkDefault
        <| inputs.themes.custom
        <|
          inputs.themes.raw.gruvbox-dark-hard
          // {
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
          };
    };

  flake.homeModules.theme = self.commonModules.theme;
}
