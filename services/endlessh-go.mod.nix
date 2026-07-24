{ self, ... }:
{
  flake.serviceModules.endlessh-go =
    {
      config,
      lib,
      options,
      ...
    }:
    let
      inherit (lib.cli) toCommandLine;
      inherit (lib.generators) mkValueStringDefault;
      inherit (lib.lists)
        any
        concatMap
        optional
        optionals
        singleton
        ;
      inherit (lib.meta) getExe;
      inherit (lib.network) familyOf isAddressV4 isAddressV6;
      inherit (lib.options) literalExpression mkOption;
      inherit (lib.strings) fromJSON hasSuffix;
      inherit (lib.types)
        addCheck
        bool
        enum
        int
        ints
        listOf
        nullOr
        package
        path
        port
        str
        submodule
        ;

      cfg = config.endlessh-go;
    in
    {
      imports = singleton self.serviceModules.base;

      options.endlessh-go = {
        package = mkOption {
          type = package;
          description = "Package providing `endlessh-go`.";
        };

        settings = mkOption {
          default = { };
          description = "Command-line settings for endlessh-go.";
          type = submodule {
            options =
              let
                address = addCheck str (value: isAddressV4 value || isAddressV6 value) // {
                  description = "IP address";
                };
              in
              {
                interval_ms = mkOption {
                  type = nullOr ints.unsigned;
                  default = null;
                  defaultText = literalExpression "1000";
                  description = "Message delay in milliseconds.";
                };

                line_length = mkOption {
                  type = nullOr ints.unsigned;
                  default = null;
                  defaultText = literalExpression "32";
                  description = "Maximum banner line length.";
                };

                max_clients = mkOption {
                  type = nullOr ints.unsigned;
                  default = null;
                  defaultText = literalExpression "4096";
                  description = "Maximum number of clients.";
                };

                conn_type = mkOption {
                  type =
                    nullOr
                    <| enum [
                      "tcp"
                      "tcp4"
                      "tcp6"
                    ];
                  default = null;
                  defaultText = literalExpression ''"tcp"'';
                  description = "Connection network type.";
                };

                host = mkOption {
                  type = nullOr address;
                  default = null;
                  defaultText = literalExpression ''"0.0.0.0"'';
                  description = "SSH listening address.";
                };

                port = mkOption {
                  type = listOf port;
                  default = [ ];
                  defaultText = literalExpression "[ 2222 ]";
                  description = "SSH listening ports.";
                };

                enable_prometheus = mkOption {
                  type = nullOr bool;
                  default = null;
                  defaultText = literalExpression "false";
                  description = "Whether to expose Prometheus metrics.";
                };

                enable_healthcheck = mkOption {
                  type = nullOr bool;
                  default = null;
                  defaultText = literalExpression "false";
                  description = "Whether to expose the health endpoint.";
                };

                prometheus_host = mkOption {
                  type = nullOr address;
                  default = null;
                  defaultText = literalExpression ''"0.0.0.0"'';
                  description = "Prometheus listening address.";
                };

                prometheus_port = mkOption {
                  type = nullOr port;
                  default = null;
                  defaultText = literalExpression "2112";
                  description = "Prometheus listening port.";
                };

                prometheus_entry = mkOption {
                  type = nullOr str;
                  default = null;
                  defaultText = literalExpression ''"metrics"'';
                  description = "Prometheus HTTP entry point.";
                };

                prometheus_clean_unseen_seconds = mkOption {
                  type = nullOr ints.unsigned;
                  default = null;
                  defaultText = literalExpression "0";
                  description = "Age after which unseen Prometheus series are removed; zero disables cleanup.";
                };

                geoip_supplier = mkOption {
                  type =
                    nullOr
                    <| enum [
                      "off"
                      "ip-api"
                      "max-mind-db"
                    ];
                  default = null;
                  defaultText = literalExpression ''"off"'';
                  description = "Supplier used to obtain IP geolocation data.";
                };

                max_mind_db = mkOption {
                  type = nullOr path;
                  default = null;
                  defaultText = literalExpression ''""'';
                  description = "Path to the MaxMind database.";
                };

                proxy_protocol_enabled = mkOption {
                  type = nullOr bool;
                  default = null;
                  defaultText = literalExpression "false";
                  description = "Whether to accept PROXY protocol headers.";
                };

                proxy_protocol_read_header_timeout_ms = mkOption {
                  type = nullOr ints.unsigned;
                  default = null;
                  defaultText = literalExpression "200";
                  description = "PROXY protocol header timeout in milliseconds.";
                };

                healthcheck_host = mkOption {
                  type = nullOr address;
                  default = null;
                  defaultText = literalExpression ''"127.0.0.1"'';
                  description = "Health endpoint listening address.";
                };

                healthcheck_port = mkOption {
                  type = nullOr port;
                  default = null;
                  defaultText = literalExpression "51000";
                  description = "Health endpoint listening port.";
                };

                alsologtostderr = mkOption {
                  type = nullOr bool;
                  default = null;
                  defaultText = literalExpression "false";
                  description = "Whether to log to standard error in addition to log files.";
                };

                log_backtrace_at = mkOption {
                  type = nullOr str;
                  default = null;
                  defaultText = literalExpression ''""'';
                  description = "File and line at which to emit a stack trace when logging.";
                };

                log_dir = mkOption {
                  type = nullOr str;
                  default = null;
                  defaultText = literalExpression ''""'';
                  description = "Directory in which to write log files.";
                };

                log_link = mkOption {
                  type = nullOr str;
                  default = null;
                  defaultText = literalExpression ''""'';
                  description = "Directory in which to create links to log files.";
                };

                logbuflevel = mkOption {
                  type = nullOr int;
                  default = null;
                  defaultText = literalExpression "0";
                  description = "Maximum severity level whose log output may be buffered.";
                };

                logtostderr = mkOption {
                  type = nullOr bool;
                  default = null;
                  defaultText = literalExpression "false";
                  description = "Whether to log to standard error instead of log files.";
                };

                stderrthreshold = mkOption {
                  type = nullOr str;
                  default = null;
                  defaultText = literalExpression "2";
                  description = "Minimum severity level copied to standard error.";
                };

                v = mkOption {
                  type = nullOr int;
                  default = null;
                  defaultText = literalExpression "0";
                  description = "Verbose logging level.";
                };

                vmodule = mkOption {
                  type = nullOr str;
                  default = null;
                  defaultText = literalExpression ''""'';
                  description = "Per-file verbose logging levels.";
                };
              };
          };
        };
      };

      config = {
        exec.again = "always";
        exec.argv =
          singleton (getExe cfg.package)
          ++ toCommandLine (name: {
            option = "--${name}";

            sep = "=";
            explicitBool = false;

            formatArg =
              value:
              if (name == "host" || hasSuffix "_host" name) && isAddressV6 value then
                "[${value}]"
              else
                mkValueStringDefault { } value;
          }) cfg.settings;

        network =
          let
            configuredOrDefault =
              name:
              let
                value = cfg.settings.${name};
              in
              if value == null || value == [ ] then
                fromJSON (options.endlessh-go.settings.type.getSubOptions [ ]).${name}.defaultText.text
              else
                value;

            effectiveFamily =
              name:
              let
                value = configuredOrDefault name;
              in
              familyOf (if configuredOrDefault "conn_type" == "tcp6" && value == "0.0.0.0" then "::" else value);
          in
          {
            reach = [
              "0.0.0.0/0"
              "::/0"
            ];

            bind =
              map (port: {
                ${effectiveFamily "host"}.tcp = port;
              }) (configuredOrDefault "port")
              ++ optional (cfg.settings.enable_healthcheck == true) {
                ${effectiveFamily "healthcheck_host"}.tcp = configuredOrDefault "healthcheck_port";
              }
              ++ optional (cfg.settings.enable_prometheus == true) {
                ${effectiveFamily "prometheus_host"}.tcp = configuredOrDefault "prometheus_port";
              };
          };

        limits.syscalls = singleton "@system-service";
        limits.capabilities = optional (
          config.network.bind
          |> concatMap (
            { v4, v6, ... }:
            optionals (v4 != null) [
              v4.tcp
              v4.udp
            ]
            ++ optionals (v6 != null) [
              v6.tcp
              v6.udp
            ]
          )
          |> any (port: port != null && port > 0 && port < 1024)
        ) "CAP_NET_BIND_SERVICE";

        ${if options ? systemd then "systemd" else null}.service = {
          description = "Endlessh SSH tarpit";
          unitConfig.Documentation = "https://github.com/shizunge/endlessh-go";

          after = singleton "network.target";
          wantedBy = singleton "multi-user.target";
        };
      };
    };
}
