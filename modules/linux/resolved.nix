{ config, lib, ... }: let
  inherit (lib) enabled;
in {
  services.resolved = enabled {
    settings.Resolve = {
      DNSSEC = true;
      DNSOverTLS = true;
      DNS = config.dns.servers;
      FallbackDNS = config.dns.serversFallback;
    };
  };
}
