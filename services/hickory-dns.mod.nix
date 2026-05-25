{
  flake.modularServices.hickory-dns =
    {
      config,
      lib,
      name,
      options,
      ...
    }:
    let
      inherit (lib.attrsets)
        filterAttrs
        isAttrs
        mapAttrs
        optionalAttrs
        ;
      inherit (lib.lists)
        isList
        map
        optional
        singleton
        ;
      inherit (lib.meta) getExe;
      inherit (lib.options) mkOption;
      inherit (lib.strings) escapeShellArgs;
      inherit (lib.types)
        coercedTo
        either
        enum
        listOf
        nullOr
        package
        path
        port
        raw
        str
        submodule
        toml
        ;

      cfg = config.hickory-dns;

      cleanToml =
        value:
        if isList value then
          map cleanToml value
        else if isAttrs value then
          value |> filterAttrs (_: value: value != null) |> mapAttrs (_: cleanToml)
        else
          value;
    in
    {
      # https://nixos.org/manual/nixos/unstable/#modular-services
      _class = "service";

      options.hickory-dns = {
        package = mkOption {
          type = package;
          description = "Package to use for hickory-dns.";
        };

        tomlFormat = mkOption {
          type = raw;
          description = "TOML format generator, usually `pkgs.formats.toml { }`.";
        };

        logLevel = mkOption {
          type = nullOr (enum [
            "debug"
            "quiet"
          ]);
          default = null;
          description = "Optional hickory-dns log level flag.";
        };

        configFile = mkOption {
          type = either path str;
          default = config.configData."hickory-dns.toml".path;
          description = "Path to the hickory-dns TOML configuration file.";
        };

        settings = mkOption {
          description = "Settings for hickory-dns, serialised to TOML.";
          type = submodule {
            freeformType = toml;
            options = {
              listen_addrs_ipv4 = mkOption {
                type = listOf str;
                default = [ ];
                description = "IPv4 addresses to listen on.";
              };

              listen_addrs_ipv6 = mkOption {
                type = listOf str;
                default = [ ];
                description = "IPv6 addresses to listen on.";
              };

              listen_port = mkOption {
                type = port;
                default = 53;
                description = "Port to listen on.";
              };

              directory = mkOption {
                type = str;
                default = "/var/lib/hickory-dns-${name}";
                description = "Directory for relative zone files.";
              };

              zones = mkOption {
                description = "List of zones to serve.";
                default = [ ];
                type =
                  listOf
                  <| coercedTo str (zone: {
                    inherit zone;
                  })
                  <| submodule (
                    { config, ... }:
                    {
                      freeformType = toml;
                      options = {
                        zone = mkOption {
                          type = str;
                          description = "Zone name, like example.com, localhost, or 0.0.127.in-addr.arpa.";
                        };

                        zone_type = mkOption {
                          type = enum [
                            "Primary"
                            "Secondary"
                            "External"
                          ];
                          default = "Primary";
                          description = "Zone type to serve.";
                        };

                        file = mkOption {
                          type = nullOr (either path str);
                          default = if config.zone_type != "External" then "${config.zone}.zone" else null;
                          description = "Path to the zone file, relative to directory unless absolute.";
                        };
                      };
                    }
                  );
              };
            };
          };
        };
      };

      config = {
        configData."hickory-dns.toml".source =
          cfg.tomlFormat.generate "hickory-dns.toml" <| cleanToml cfg.settings;

        process.argv = [
          (getExe cfg.package)
          "--config"
          cfg.configFile
        ]
        ++ optional (cfg.logLevel != null) "--${cfg.logLevel}";
      }
      // optionalAttrs (options ? launchd) {
        launchd = {
          KeepAlive = true;
          ProgramArguments = [
            "/bin/sh"
            "-c"
            /* bash */ ''
              /bin/wait4path /nix/store && exec ${escapeShellArgs config.process.argv}
            ''
          ];
          RunAtLoad = true;
        };
      }
      // optionalAttrs (options ? systemd) {
        systemd.service = {
          description = "Hickory Domain Name Server";
          unitConfig.Documentation = "https://hickory-dns.org/";

          after = singleton "network.target";
          wantedBy = singleton "multi-user.target";

          serviceConfig = {
            Restart = "on-failure";
            RestartSec = "10s";
            DynamicUser = true;

            StateDirectory = "hickory-dns-${name}";
            ReadWritePaths = singleton cfg.settings.directory;

            AmbientCapabilities = singleton "CAP_NET_BIND_SERVICE";
            CapabilityBoundingSet = singleton "CAP_NET_BIND_SERVICE";
            LockPersonality = true;
            MemoryDenyWriteExecute = true;
            NoNewPrivileges = true;
            PrivateDevices = true;
            PrivateMounts = true;
            PrivateTmp = true;
            ProtectClock = true;
            ProtectControlGroups = true;
            ProtectHome = true;
            ProtectHostname = true;
            ProtectKernelLogs = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            ProtectProc = "invisible";
            ProtectSystem = "full";
            RemoveIPC = true;
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
            ];
            RestrictNamespaces = true;
            RestrictSUIDSGID = true;
            SystemCallArchitectures = "native";
            SystemCallFilter = [
              "@system-service"
              "~@privileged"
              "~@resources"
            ];
          };
        };
      };
    };
}
