{
  flake.nixosModules.metrics-exporter =
    { config, lib, ... }:
    let
      inherit (lib.modules) mkIf;
    in
    {
      services.prometheus.exporters.node = mkIf config.isServer {
        enable = true;
        enabledCollectors = [
          "processes"
          "systemd"
        ];
        listenAddress = "[::]";
      };
    };

  # TODO: nixosModules.metrics-server (prometheus + grafana)
}
