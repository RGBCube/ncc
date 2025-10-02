{ config, lib, pkgs, ... }: let
  inherit (lib) mkAliasOptionModule mkIf;
in {
  imports = [(mkAliasOptionModule [ "secrets" ] [ "age" "secrets" ])];

  age.identityPaths = [
    (if config.isLinux then
      "/root/.ssh/id"
    else
      "/Users/${config.system.primaryUser}/.ssh/id")
  ];

  environment = mkIf config.isDesktop {
    shellAliases.agenix = "agenix --identity ~/.ssh/id";
    systemPackages      = [
      pkgs.ragenix
    ];
  };
}
