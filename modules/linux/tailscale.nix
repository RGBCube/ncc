{ config, lib, pkgs, ... }: let
  inherit (lib) enabled mkIf getExe;

  # Shorter is better for networking interfaces IMO.
  interface = "ts0";
in {
  # This doesn't work with dig but works with curl, Zen
  # and all other tools. Skill issue.
  services.resolved.settings.Resolve.Domains = [ "warthog-major.ts.net" ];

  services.tailscale = enabled {
    interfaceName      = interface;
    useRoutingFeatures = "both";
  };

  networking.firewall.trustedInterfaces = [ interface ];

  systemd.services.tailscaled.serviceConfig.Environment = mkIf config.networking.nftables.enable [
    "TS_DEBUG_FIREWALL_MODE=nftables" 
  ];

  systemd.network.wait-online.enable = false; 
  boot.initrd.systemd.network.wait-online.enable = false;

  services.networkd-dispatcher = enabled {
    rules."50-tailscale-optimizations" = {
      onState = [ "routable" ];
      script = /* sh */ ''
        ${getExe pkgs.ethtool} --features ${config.networking.defaultGateway.interface} rx-udp-gro-forwarding on rx-gro-list off
      '';
    };
  };
}
