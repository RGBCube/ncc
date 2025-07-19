{ lib, ... }: let
  inherit (lib) enabled;
in {
  home-manager.sharedModules = [{
    programs.direnv = enabled {
      nix-direnv = enabled;
    };
  }];
}
