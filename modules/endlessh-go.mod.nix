{
  nixosModules.endlessh-go =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.modules) mkEnableOption mkOption;
      inherit (lib.types) str port;
    in
    {
      # And yes, I've tried lib.mkAliasOptionModule.
      # It doesn't work for a mysterious reason,
      # says it can't find `services.prometheus.exporters.endlessh-go`.
      #
      # This works, however.
      #
      # TODO: I may be stupid, because the above note says that I tried
      # to alias to a nonexistent option, rather than the other way around.
      # Let's try mkAliasOptionModule again later.
      options.services.prometheus.exporters.endlessh-go = {
        enable = mkEnableOption "Prometheus integration";

        listenAddress = mkOption {
          type = str;
          default = "0.0.0.0";
        };

        port = mkOption {
          type = port;
          default = 2112;
        };
      };

      config.services.prometheus.exporters.endlessh-go = {
        enable = true;

        listenAddress = "[::]";
      };

      # `services.endlessh-go.openFirewall` exposes both the Prometheus
      # exporters port and the SSH port, and we don't want the metrics
      # to leak, so we manually expose this like so.
      config.networking.firewall.allowedTCPPorts = [ config.services.endlessh-go.port ];

      config.services.endlessh-go = {
        enable = true;

        listenAddress = "[::]";
        port = 2222;

        extraOptions = [
          "-alsologtostderr"
          "-geoip_supplier max-mind-db"
          "-max_mind_db ${pkgs.dbip-country-lite}/share/dbip/dbip-country-lite.mmdb"
        ];

        prometheus = config.services.prometheus.exporters.endlessh-go;
      };
    };
}
