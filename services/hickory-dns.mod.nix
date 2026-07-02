{ self, ... }:
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
        getAttr
        ;
      inherit (lib.filesystem) dirOf;
      inherit (lib.lists)
        any
        concatMap
        elem
        filter
        isList
        last
        map
        optional
        optionals
        singleton
        unique
        ;
      inherit (lib.meta) getExe';
      inherit (lib.network) familyOf isAddressV6 isLoopback;
      inherit (lib.options) literalExpression mkOption;
      inherit (lib.strings) splitString toInt;
      inherit (lib.trivial) flip;
      inherit (lib.types)
        bool
        enum
        ints
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

      imports = singleton self.modularServices.base;

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
          type =
            nullOr
            <| enum [
              "debug"
              "quiet"
            ];
          default = null;
          description = "Optional hickory-dns log level flag.";
        };

        settings = mkOption {
          description = "Settings for hickory-dns, serialised to TOML.";
          type = submodule {
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
                description = "Port on which to listen (associated to all IPs)";
              };

              tls_listen_port = mkOption {
                type = nullOr port;
                default = null;
                defaultText = literalExpression "853";
                description = "Secure port to listen on";
              };

              https_listen_port = mkOption {
                type = nullOr port;
                default = null;
                defaultText = literalExpression "443";
                description = "HTTPS port to listen on";
              };

              quic_listen_port = mkOption {
                type = nullOr port;
                default = null;
                defaultText = literalExpression "853";
                description = "QUIC port to listen on";
              };

              prometheus_listen_addr = mkOption {
                type = nullOr str;
                default = null;
                description = "Prometheus listen address";
              };

              disable_tcp = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Disable TCP protocol";
              };

              disable_udp = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Disable UDP protocol";
              };

              disable_tls = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Disable TLS protocol";
              };

              disable_https = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Disable HTTPS protocol";
              };

              disable_quic = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Disable QUIC protocol";
              };

              disable_prometheus = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Disable Prometheus metrics";
              };

              tcp_request_timeout = mkOption {
                type = nullOr ints.unsigned;
                default = null;
                defaultText = literalExpression "5";
                description = "Timeout associated to a request before it is closed.";
              };

              ssl_keylog_enabled = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = ''
                  Whether to respect the SSLKEYLOGFILE environment variable.

                  This should only be enabled WITH CARE! When enabled, and the SSLKEYLOGFILE environment
                  variable is set, TLS session keys will be logged to the filepath specified by the
                  environment variable value.

                  This is principally useful for decrypting captured packet data with tools like Wireshark.
                '';
              };

              directory = mkOption {
                type = str;
                default = dirOf config.configData."hickory-dns.toml".path;
                description = "Directory for relative zone files.";
              };

              user = mkOption {
                type = nullOr str;
                default = null;
                description = ''
                  User to run the server as.

                  Only supported on Unix-like platforms. If the real or effective UID of the hickory process
                  is root, we will attempt to change to this user (or to nobody if no user is specified here.)
                '';
              };

              group = mkOption {
                type = nullOr str;
                default = null;
                description = ''
                  Group to run the server as.

                  Only supported on Unix-like platforms. If the real or effective UID of the hickory process
                  is root, we will attempt to change to this group (or to nobody if no group is specified here.)
                '';
              };

              zones = mkOption {
                description = "List of zones to serve.";
                default = [ ];
                type =
                  listOf
                  <| submodule {
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
                        description = "Zone type to serve.";
                      };

                      file = mkOption {
                        type = nullOr path;
                        default = null;
                        description = "Path to the zone file, relative to directory unless absolute.";
                      };

                      axfr_policy = mkOption {
                        type =
                          nullOr
                          <| enum [
                            "Deny"
                            "AllowAll"
                            "AllowSigned"
                          ];
                        default = null;
                        defaultText = literalExpression ''"Deny"'';
                        description = ''
                          A policy used to determine whether AXFR requests are allowed

                          By default, all AXFR requests are rejected
                        '';
                      };

                      keys = mkOption {
                        type =
                          nullOr
                          <| listOf
                          <| submodule {
                            options = {
                              key_path = mkOption {
                                type = str;
                                description = "file path to the key";
                              };

                              algorithm = mkOption {
                                type = enum [
                                  "RSASHA256"
                                  "RSASHA512"
                                  "ECDSAP256SHA256"
                                  "ECDSAP384SHA384"
                                  "ED25519"
                                ];
                                description = "the type of key stored";
                              };

                              signer_name = mkOption {
                                type = nullOr str;
                                default = null;
                                description = "the name to use when signing records, e.g. ns.example.com";
                              };
                            };
                          };
                        default = null;
                        defaultText = literalExpression "[ ]";
                        description = "Keys for use by the zone";
                      };

                      nx_proof_kind = mkOption {
                        type = nullOr toml;
                        default = null;
                        description = "The kind of non-existence proof provided by the nameserver";
                      };

                      stores = mkOption {
                        type = nullOr toml;
                        default = null;
                        description = ''
                          Store configurations, a table or list of chained
                          tables, each tagged by `type`: `file` or `sqlite` on
                          Primary and Secondary zones, `blocklist`, `forward`
                          or `recursor` on External zones.
                        '';
                      };
                    };
                  };
              };

              tls_cert = mkOption {
                type =
                  nullOr
                  <| submodule {
                    options = {
                      path = mkOption {
                        type = str;
                        description = "Path to the PEM certificate chain, relative to directory unless absolute.";
                      };

                      endpoint_name = mkOption {
                        type = nullOr str;
                        default = null;
                        description = "Name of the endpoint the certificate is served for.";
                      };

                      private_key = mkOption {
                        type = str;
                        description = "Path to the PEM or DER private key, relative to directory unless absolute.";
                      };
                    };
                  };
                default = null;
                description = "Certificate to associate to TLS connections (currently the same is used for HTTPS and TLS)";
              };

              http_endpoint = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''"/dns-query"'';
                description = ''
                  The HTTP endpoint where the DNS-over-HTTPS server provides service. Applicable
                  to both HTTP/2 and HTTP/3 servers. Typically `/dns-query`.
                '';
              };

              deny_networks = mkOption {
                type = nullOr <| listOf str;
                default = null;
                defaultText = literalExpression "[ ]";
                description = "Networks denied to access the server";
              };

              allow_networks = mkOption {
                type = nullOr <| listOf str;
                default = null;
                defaultText = literalExpression "[ ]";
                description = "Networks allowed to access the server";
              };

              udp_socket = mkOption {
                type =
                  nullOr
                  <| submodule {
                    options = {
                      recv_buffer_size = mkOption {
                        type = nullOr ints.unsigned;
                        default = null;
                        description = ''
                          UDP socket receive buffer size in bytes.

                          Controls the kernel buffer for incoming UDP packets. If not specified, the operating
                          system default is used. Larger values help absorb traffic bursts without dropping
                          packets.
                        '';
                      };

                      send_buffer_size = mkOption {
                        type = nullOr ints.unsigned;
                        default = null;
                        description = ''
                          UDP socket send buffer size in bytes.

                          Controls the kernel buffer for outgoing UDP packets. If not specified, the operating
                          system default is used. Larger values help when the server is sending many responses.
                        '';
                      };

                      sockets = mkOption {
                        type = nullOr ints.positive;
                        default = null;
                        defaultText = literalExpression "1";
                        description = ''
                          Number of UDP sockets to create per listen address (Unix only).

                          Using multiple sockets with SO_REUSEPORT allows the kernel to distribute incoming packets
                          across sockets, which may improve performance under high load. Optimal values depend
                          on workload and setting it too high will have the opposite effect and cause performance
                          degradation.
                        '';
                      };
                    };
                  };
                default = null;
                description = "UDP socket configuration options.";
              };

              tcp_socket = mkOption {
                type =
                  nullOr
                  <| submodule {
                    options = {
                      listen_backlog = mkOption {
                        type = nullOr ints.unsigned;
                        default = null;
                        defaultText = literalExpression "128";
                        description = ''
                          TCP listen backlog size.

                          Controls the maximum number of pending connections queued by the kernel before
                          connections are refused. If not specified, defaults to 128.

                          Higher values allow more connections to queue during traffic spikes.
                          Consider increasing this for high-TCP load deployments.

                          On Linux the kernel `net.core.somaxconn` and `net.ipv[4|6].tcp_max_syn_backlog`
                          may also need adjustment to match.
                        '';
                      };

                      response_buffer_size = mkOption {
                        type = nullOr ints.unsigned;
                        default = null;
                        defaultText = literalExpression "32";
                        description = ''
                          TCP response buffer size.

                          Controls the maximum number of DNS responses that can be queued for
                          sending on a single TCP connection. Under high query rates, a larger
                          buffer prevents responses from being dropped due to backpressure.

                          If not specified, defaults to 32.
                        '';
                      };
                    };
                  };
                default = null;
                description = "TCP socket configuration options.";
              };
            };
          };
        };
      };

      config = {
        configData."hickory-dns.toml".source =
          cfg.tomlFormat.generate "hickory-dns.toml" <| cleanToml cfg.settings;

        limits.syscalls = singleton "@system-service";
        limits.capabilities = singleton "CAP_NET_BIND_SERVICE";

        files.${cfg.settings.directory} = singleton "read";

        exec.again = "always";
        exec.argv = [
          (getExe' cfg.package "hickory-dns")
          "--config"
          config.configData."hickory-dns.toml".path
        ]
        ++ optional (cfg.logLevel != null) "--${cfg.logLevel}";

        network =
          let
            nameservers = cfg.settings.zones |> concatMap (zone: zone.stores.name_servers or [ ]);
            listenAddrs = cfg.settings.listen_addrs_ipv4 ++ cfg.settings.listen_addrs_ipv6;

            configuredOrDefaultPort =
              name:
              if cfg.settings.${name} != null then
                cfg.settings.${name}
              else
                toInt (options.hickory-dns.settings.type.getSubOptions [ ]).${name}.defaultText.text;

            # An entry for each family that has listeners.
            onActive = protocols: {
              ${if cfg.settings.listen_addrs_ipv4 != [ ] then "v4" else null} = protocols;
              ${if cfg.settings.listen_addrs_ipv6 != [ ] then "v6" else null} = protocols;
            };
          in
          {
            reach =
              if listenAddrs |> any (ip: !isLoopback ip) then
                [
                  "0.0.0.0/0"
                  "::/0"
                ]
              else
                [
                  "127.0.0.0/8"
                  "::1/128"
                ]
                ++ (
                  listenAddrs ++ map (getAttr "ip") nameservers
                  |> map (ip: "${ip}/${if isAddressV6 ip then "128" else "32"}")
                );

            bind =
              (
                nameservers
                |> filter (
                  nameserver:
                  nameserver.connections or [ ]
                  |> map (connection: connection.protocol.type or "udp")
                  |> (
                    protocols:
                    protocols == [ ]
                    || any (flip elem [
                      "udp"
                      "quic"
                      "h3"
                    ]) protocols
                  )
                )
                |> map ({ ip, ... }: familyOf ip)
                |> unique
                |> map (family: {
                  ${family}.udp = 0;
                })
              )
              ++ singleton (onActive {
                tcp = cfg.settings.listen_port;
                udp = cfg.settings.listen_port;
              })
              ++ optionals (cfg.settings.tls_cert != null) [
                (onActive { tcp = configuredOrDefaultPort "tls_listen_port"; })
                (onActive { tcp = configuredOrDefaultPort "https_listen_port"; })
                (onActive { udp = configuredOrDefaultPort "quic_listen_port"; })
              ]
              ++ optional (cfg.settings.prometheus_listen_addr != null) {
                ${familyOf cfg.settings.prometheus_listen_addr}.tcp =
                  cfg.settings.prometheus_listen_addr
                  |> splitString ":"
                  |> last
                  |> toInt;
              };
          };

        ${if options ? systemd then "systemd" else null}.service = {
          description = "Hickory Domain Name Server";
          unitConfig.Documentation = "https://hickory-dns.org/";

          after = singleton "network.target";
          wantedBy = singleton "multi-user.target";

          restartTriggers = singleton config.configData."hickory-dns.toml".source;
        };
      };
    };
}
