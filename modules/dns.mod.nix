{ self, lib, ... }:
let
  inherit (lib.magic) ula;

  address = "${ula "resolver"}::1";

  mkPackage =
    { pkgs, lib }:
    let
      inherit (lib.fixedPoints) fix;
      inherit (lib.lists)
        elem
        optional
        singleton
        subtractLists
        unique
        ;
      inherit (lib) platforms;
    in
    pkgs.hickory-dns.overrideAttrs (
      old:
      let
        oldBuildFeatures = old.cargoBuildFeatures or (old.buildFeatures or [ ]);
        oldCheckFeatures = old.cargoCheckFeatures or (old.checkFeatures or oldBuildFeatures);

        replaceRingFeatures =
          features:
          (
            features
            |> subtractLists [
              "dnssec-ring"
              "h3-ring"
              "https-ring"
              "quic-ring"
              "tls-ring"
            ]
          )
          ++ optional (elem "dnssec-ring" features) "dnssec-aws-lc-rs"
          ++ [
            "h3-aws-lc-rs"
            "https-aws-lc-rs"
            "quic-aws-lc-rs"
            "tls-aws-lc-rs"
          ]
          |> unique;
      in
      fix (final: {
        version = "0.27.0-alpha.1";

        src = pkgs.fetchFromGitHub {
          owner = "RGBCube";
          repo = "hickory-dns";
          rev = "2c67598a63b0d568bc46740a793602b1b509e3ed";
          hash = "sha256-n0z3MdiDWyUkoPEkQAJCP7bMWCwHsw7f3MGOZp3t+VU=";
        };

        cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
          inherit (final) src;
          name = "hickory-dns-${final.version}-vendor";
          hash = "sha256-G0Hk1+kETK3pT3ZF0oCh07Eptm4BShFVpDt6k8xegHQ=";
        };

        buildFeatures = final.cargoBuildFeatures;
        checkFeatures = final.cargoCheckFeatures;
        cargoBuildFeatures = replaceRingFeatures oldBuildFeatures;
        cargoCheckFeatures = replaceRingFeatures oldCheckFeatures;

        env = (old.env or { }) // {
          AWS_LC_SYS_CMAKE_BUILDER = 1;
          LIBSQLITE3_SYS_USE_PKG_CONFIG = 1;
        };

        buildInputs = (old.buildInputs or [ ]) ++ singleton pkgs.sqlite;

        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
          pkgs.cmake
          pkgs.pkg-config
        ];

        meta.platforms = old.meta.platforms ++ platforms.darwin;
      })
    );
in
{

  flake.commonModules.authoritative =
    {
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) mapAttrsToList;
      inherit (lib.lists) imap0 singleton;
      inherit (lib.strings) concatLines;
    in
    {
      system.services.authoritative = {
        imports = singleton self.modularServices.hickory-dns;

        hickory-dns = {
          package = mkPackage { inherit pkgs lib; };
          tomlFormat = pkgs.formats.toml { };

          settings = {
            listen_addrs_ipv4 = singleton "0.0.0.0";
            listen_addrs_ipv6 = singleton "::";
            listen_port = 53;

            zones =
              let
                zone = "hate.software.";
              in
              singleton {
                inherit zone;
                zone_type = "Primary";
                axfr_policy = "AllowAll";
                file = "${pkgs.writeText "${zone}zone" /* zone */ ''
                  $ORIGIN ${zone}
                  $TTL 1h

                  @ SOA 0.ns hostmaster (
                    2026052805 ; serial   ; Bump on EVERY edit (YYYYMMDDnn)
                    2h         ; refresh  ; Consulted only by secondaries.
                    15m        ; retry    ; Consulted only by secondaries.
                    2w         ; expire   ; secondary stops serving after this long unreachable
                    1h         ; minimum  ; negative-cache TTL
                  )

                  ns CNAME 0.ns ; Friendly alias for the primary.

                  ${
                    [
                      {
                        A = "159.146.61.20";
                        # AAAA = "2a02:ff0:3d0e:ca89::53"; # TODO: Uncomment once public v6 is set up.
                      }
                      {
                        A = "159.146.61.20";
                        # AAAA = "2a02:ff0:3d0e:ca89::53"; # TODO: Uncomment once public v6 is set up.
                      }
                    ]
                    |> imap0 (
                      i: records:
                      singleton ''
                        @ NS ${toString i}.ns
                      ''
                      ++ mapAttrsToList (type: value: ''
                        ${toString i}.ns ${type} ${value}
                      '') records
                      |> concatLines
                    )
                    |> concatLines
                  }

                  ; CONTENT
                  xn--67-lubb0090b HINFO "Tendril" "hey, hater"
                ''}";
              };
          };
        };
      };
    };

  flake.nixosModules.authoritative =
    { config, lib, ... }:
    let
      inherit (lib.attrsets) genAttrs;
      inherit (lib.trivial) const;
      inherit (lib.lists) singleton;
      inherit (lib.modules) mkIf;
    in
    {
      networking.firewall =
        genAttrs [
          "allowedTCPPorts"
          "allowedUDPPorts"
        ]
        <| const
        <| singleton 53;

      # TCP SO_REUSEADDR + SO_REUSEPORT only works if both clients are on the same UID.
      systemd.services =
        mkIf (config.system.services ? resolver)
        <| genAttrs [ "authoritative" "resolver" ] (const {
          serviceConfig = {
            User = "hickory-dns";
            Group = "hickory-dns";
          };
        });
    };

  flake.commonModules.resolver =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) map singleton;
      inherit (lib.strings) substring;

      id = "7f2bf8";
      idv6 = "${substring 0 2 id}:${substring 2 4 id}";

      mkNextDnsServer =
        { ip, hostName }:
        {
          inherit ip;
          trust_negative_responses = true;
          connections = [
            {
              protocol = {
                type = "h3";
                server_name = "dns.nextdns.io";
                path = "/${id}/${hostName}";
              };
            }
            {
              protocol = {
                type = "quic";
                server_name = "${hostName}-${id}.dns.nextdns.io";
              };
            }
            {
              protocol = {
                type = "https";
                server_name = "dns.nextdns.io";
                path = "/${id}/${hostName}";
              };
            }
            {
              protocol = {
                type = "tls";
                server_name = "${hostName}-${id}.dns.nextdns.io";
              };
            }
          ];
        };
    in
    {
      system.services.resolver = {
        imports = singleton self.modularServices.hickory-dns;

        hickory-dns = {
          package = mkPackage { inherit pkgs lib; };

          tomlFormat = pkgs.formats.toml { };

          settings = {
            listen_addrs_ipv6 = singleton address;
            listen_port = 53;

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
                  {
                    inherit (config.networking) hostName;
                    ip = "45.90.28.0";
                  }
                  {
                    inherit (config.networking) hostName;
                    ip = "45.90.30.0";
                  }
                ]
                |> map mkNextDnsServer;
            };
          };
        };
      };
    };

  flake.darwinModules.resolver =
    { lib, pkgs, ... }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkBefore;
    in
    {
      networking.dns = singleton address;

      system.services.resolver.launchd.ProgramArguments =
        mkBefore
        <| singleton
        <| "${pkgs.writeScript "resolver-setup-address" /* nu */ ''
          #!${getExe pkgs.nushell}
          #

          def --wrapped main [...rest] {
            try { ^/sbin/ifconfig lo0 inet6 ${address}/128 alias }
            exec ...$rest
          }
        ''}";
    };

  flake.nixosModules.resolver =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      services.resolved.enable = false;
      networking.resolvconf.enable = false;

      networking.interfaces.lo.ipv6.addresses = singleton {
        inherit address;
        prefixLength = 128;
      };

      systemd.services.resolver = {
        after = singleton "network-addresses-lo.service";
        bindsTo = singleton "network-addresses-lo.service";
      };

      environment.etc."resolv.conf".text = /* resolvconf */ ''
        # Generated by NixOS modules, should use the Hickory resolver.
        options edns0 trust-ad
        nameserver ${address}
      '';
    };
}
