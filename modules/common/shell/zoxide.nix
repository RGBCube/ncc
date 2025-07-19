{ lib, ... }: let
  inherit (lib) enabled;
in {
  home-manager.sharedModules = [{
    programs.zoxide = enabled {
      options = [ "--cmd cd" ];
    };
  }];
}
