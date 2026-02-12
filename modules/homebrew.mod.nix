{ inputs, ... }:
{
  flake.darwinModules.homebrew =
    { config, ... }:
    {
      imports = [ inputs.homebrew.darwinModules.nix-homebrew ];

      homebrew.enable = true;

      nix-homebrew = {
        enable = true;

        user = config.system.primaryUser;

        taps."homebrew/homebrew-core" = inputs.homebrew-core;
        taps."homebrew/homebrew-cask" = inputs.homebrew-cask;

        mutableTaps = false;
      };
    };
}
