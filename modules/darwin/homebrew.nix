{ homebrew-core, homebrew-cask, config, lib, ... }: let
  inherit (lib) enabled;
in {
  homebrew = enabled;

  nix-homebrew = enabled {
    user = config.system.primaryUser;

    taps."homebrew/homebrew-core" = homebrew-core;
    taps."homebrew/homebrew-cask" = homebrew-cask;

    mutableTaps = false;
  };
}
