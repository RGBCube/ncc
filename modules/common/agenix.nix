{ config, lib, pkgs, ... }: let
  inherit (lib) attrNames filterAttrs hasPrefix head mkAliasOptionModule mkIf;
in {
  imports = [(mkAliasOptionModule [ "secrets" ] [ "age" "secrets" ])];

  age.identityPaths = [
    (if config.isLinux then
      "/root/.ssh/id"
    else
      "/Users/${head <| attrNames <| filterAttrs (_: value: value.home != null && hasPrefix "/Users/" value.home) config.users.users}/.ssh/id")
  ];

  environment = mkIf config.isDesktop {
    shellAliases.agenix = "agenix --identity ~/.ssh/id";
    systemPackages      = [
      pkgs.agenix
    ];
  };
}
