let
  domain = "warthog-major.ts.net.";
in
{
  flake.nixosModules.tailscale =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkAfter mkIf;
    in
    {
      services.tailscale = {
        enable = true;

        interfaceName = "ts0";
        useRoutingFeatures = "both";
      };

      networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];

      etc."resolv.conf".text = mkAfter ''
        search ${domain}
      '';

      # NFTABLES
      systemd.services.tailscaled.serviceConfig.Environment = mkIf config.networking.nftables.enable [
        "TS_DEBUG_FIREWALL_MODE=nftables"
      ];

      # UDP GRO FORWARDING OPTIMIZATION
      services.networkd-dispatcher = {
        enable = true;
        rules."50-tailscale-optimizations" = {
          onState = [ "routable" ];
          script = /* sh */ ''
            ${getExe pkgs.ethtool} --features ${config.networking.defaultGateway.interface} rx-udp-gro-forwarding on rx-gro-list off
          '';
        };
      };

      # WAIT-ONLINE
      systemd.network.wait-online.enable = false;
      boot.initrd.systemd.network.wait-online.enable = false;
    };

  flake.darwinModules.tailscale =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      homebrew.casks = [ "tailscale-app" ];

      networking.search = singleton domain;
    };

  flake.homeModules.tailscale =
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
