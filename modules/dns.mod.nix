{ self, lib, ... }:
let
  inherit (lib.strings) hasInfix substring;

  mkSocketAddr =
    { ip, port }: if hasInfix ":" ip then "[${ip}]:${toString port}" else "${ip}:${toString port}";

  id = "7f2bf8";
  idv6 = "${substring 0 2 id}:${substring 2 4 id}";

  mkNextDnsServers =
    { ip, hostName }:
    [
      {
        socket_addr = mkSocketAddr {
          inherit ip;
          port = 443;
        };
        protocol = "h3";
        tls_dns_name = "dns.nextdns.io";
        http_endpoint = "/${id}/${hostName}";
        trust_negative_responses = true;
      }
      {
        socket_addr = mkSocketAddr {
          inherit ip;
          port = 853;
        };
        protocol = "quic";
        tls_dns_name = "${hostName}-${id}.dns.nextdns.io";
        trust_negative_responses = true;
      }
      {
        socket_addr = mkSocketAddr {
          inherit ip;
          port = 443;
        };
        protocol = "https";
        tls_dns_name = "dns.nextdns.io";
        http_endpoint = "/${id}/${hostName}";
        trust_negative_responses = true;
      }
      {
        socket_addr = mkSocketAddr {
          inherit ip;
          port = 853;
        };
        protocol = "tls";
        tls_dns_name = "${hostName}-${id}.dns.nextdns.io";
        trust_negative_responses = true;
      }
    ];

  commonModule =
    { config, ... }:
    let
      inherit (lib.attrsets) getAttr;
      inherit (lib.lists)
        concatMap
        imap0
        singleton
        sort
        ;
    in
    {
      services.hickory-dns = {
        enable = true;
        settings = {
          listen_port = 53;
          listen_addrs_ipv6 = singleton "::";

          zones = singleton {
            zone = ".";
            zone_type = "External";

            stores.type = "forward";
            stores.name_servers =
              [
                # { # FIXME: Slow.
                #   inherit (config.networking) hostName;
                #   ip = "2a07:a8c0::${idv6}";
                # }
                # {
                #   inherit (config.networking) hostName;
                #   ip = "2a07:a8c1::${idv6}";
                # }
                # {
                #   inherit (config.networking) hostName;
                #   ip = "45.90.28.0";
                # }
                {
                  inherit (config.networking) hostName;
                  ip = "45.90.30.0";
                }
              ]
              |> concatMap mkNextDnsServers
              |> imap0 (index: server: { inherit index server; })
              |> sort (
                a: b:
                let
                  protocolPriority =
                    protocol:
                    if protocol == "h3" then
                      0
                    else if protocol == "quic" then
                      1
                    else if protocol == "https" then
                      2
                    else if protocol == "tls" then
                      3
                    else
                      67;

                  aPriority = protocolPriority a.server.protocol;
                  bPriority = protocolPriority b.server.protocol;
                in
                if aPriority == bPriority then a.index < b.index else aPriority < bPriority
              )
              |> map (getAttr "server");
          };
        };
      };
    };
in
{
  flake.darwinModules.hickory-dns =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib.meta) getExe';
      inherit (lib.modules) mkIf;
      inherit (lib.options) mkEnableOption mkOption mkPackageOption;
      inherit (lib.types)
        listOf
        path
        port
        str
        ;

      cfg = config.services.hickory-dns;
      toml = pkgs.formats.toml { };
    in
    {
      options.services.hickory-dns = {
        enable = mkEnableOption "hickory-dns";

        package = mkPackageOption pkgs "hickory-dns" { };

        configFile = mkOption {
          type = path;
          default = toml.generate "hickory-dns.toml" cfg.settings;
          description = "Path to the hickory-dns TOML configuration file.";
        };

        settings = mkOption {
          description = "Settings for hickory-dns, serialised to TOML.";
          type = lib.types.submodule {
            freeformType = toml.type;
            options = {
              listen_addrs_ipv4 = mkOption {
                type = listOf str;
                default = [ "0.0.0.0" ];
                description = "IPv4 addresses to listen on.";
              };

              listen_addrs_ipv6 = mkOption {
                type = listOf str;
                default = [ "::" ];
                description = "IPv6 addresses to listen on.";
              };

              listen_port = mkOption {
                type = port;
                default = 53;
                description = "Port to listen on.";
              };

              zones = mkOption {
                description = "List of zones to serve.";
                default = [ ];
                type = listOf toml.type;
              };
            };
          };
        };
      };

      config = mkIf cfg.enable {
        launchd.daemons.hickory-dns.serviceConfig = {
          ProgramArguments = [
            (getExe' cfg.package "hickory-dns")
            "--config"
            "${cfg.configFile}"
          ];
          KeepAlive = true;
          RunAtLoad = true;
        };
      };
    };

  flake.darwinModules.dns =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      imports = [
        commonModule

        self.darwinModules.hickory-dns
      ];

      services.hickory-dns.package = pkgs.hickory-dns.overrideAttrs (old: {
        cargoBuildFeatures = (old.cargoBuildFeatures or [ ]) ++ [
          "tls-aws-lc-rs"
          "https-aws-lc-rs"
          "quic-aws-lc-rs"
          "h3-aws-lc-rs"
        ];

        meta.platforms = old.meta.platforms ++ lib.platforms.darwin;
      });

      networking.dns = [
        "::1"
        "127.0.0.1"
      ];
    };

  flake.nixosModules.dns =
    { config, ... }:
    {
      imports = [ commonModule ];

      etc."resolv.conf".text = /* resolvconf */ ''
        # Generated by NixOS modules, should use the Hickory-DNS forwarder.
        options edns0 trust-ad
        nameserver ::1 127.0.0.1
      '';
    };
}
