{ config, lib, ... }: let
  inherit (lib) enabled concatStringsSep;
in {
  services.resolved = enabled {
    dnssec     = "true";
    # dnsovertls = "true"; # FIXME TODO After 257.8 -> 257.9

    extraConfig = config.dns.servers
      |> map (server: "DNS=${server}")
      |> concatStringsSep "\n";

    fallbackDns = config.dns.serversFallback;
  };
}
