{ lib, pkgs, ... }: let
  inherit (lib) enabled;
in {
  environment.systemPackages = [
    pkgs.carapace
    pkgs.fish
    pkgs.zsh
    pkgs.inshellisense
  ];

  home-manager.sharedModules = [{
    programs.carapace = enabled;
  }];
}
