{ config, lib, ... }: let
  inherit (lib) enabled mkIf;

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
}
