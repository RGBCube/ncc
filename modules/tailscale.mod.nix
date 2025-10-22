{
  nixosModules.tailscale =
    { config, ... }:
    {
      # TODO: Add search domain warthog-major.ts.net.
      services.hickory-dns.settings = { };

      services.tailscale = {
        enable = true;

        interfaceName = "ts0";
        useRoutingFeatures = "both";
      };

      networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];
    };

  darwinModules.tailscale = {
    homebrew.casks = [ "tailscale" ];
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
        if config.nixpkgs.hostPlatform.isLinux then getExe pkgs.tailscale else "tailscale";

      packages = mkIf config.nixpkgs.hostPlatform.isLinux [
        package
      ];
    };
}
