{ lib, pkgs, ... }: let
  inherit (lib) attrValues enabled;
in {
  environment.systemPackages = attrValues {
    inherit (pkgs)
      carapace
      fish
      zsh
      inshellisense
    ;
  };

  home-manager.sharedModules = [{
    programs.carapace = enabled;
  }];
}
