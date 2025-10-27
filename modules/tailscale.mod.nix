let
  domain = "warthog-major.ts.net.";
in
{
  nixosModules.tailscale =
    { config, lib, ... }:
    let
      inherit (lib.modules) mkAfter;
    in
    {
      services.tailscale = {
        enable = true;

        interfaceName = "ts0";
        useRoutingFeatures = "both";
      };

      networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];

      etc."resolf.conf".text = mkAfter ''
        search ${domain}
      '';
    };

  darwinModules.tailscale =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      homebrew.casks = [ "tailscale" ];

      networking.search = singleton domain;
    };

  homeModules.tailscale =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkIf;

      package = pkgs.tailscale;
    in
    {
      programs.nushell.aliases.ts =
        if config.nixpkgs.hostPlatform.isDarwin then "tailscale" else getExe pkgs.tailscale;

      packages = mkIf config.nixpkgs.hostPlatform.isLinux [
        package
      ];
    };
}
