{ self, lib, ... }:
let
  inherit (lib.dns) withClass;
  inherit (lib.magic) ula;
  inherit (lib.lists) singleton;

  address = "${ula "resolver"}::1";

  apex = self.dns.software.hate;

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
  flake.dns.software.hate = {
    SOA = {
      mname = apex.ns."0".FQDN;
      rname = apex.FQDN ++ singleton "hostmaster";
      serial = 2026061000; # Bump on EVERY edit (YYYYMMDDnn).
      refresh = "2h"; # Consulted only by secondaries.
      retry = "15m"; # Consulted only by secondaries.
      expire = "2w"; # Secondary stops serving after this long unreachable.
      minimum = "1h"; # Negative-cache TTL.
    };

    NS = [
      apex.ns."0".FQDN
      apex.ns."1".FQDN
    ];

    ns = {
      # Friendly alias for the primary.
      CNAME = apex.ns."0".FQDN;

      "0".A = "159.146.61.20";
      # "0".AAAA = "2a02:ff0:3d0e:ca89::53"; # TODO: Uncomment once public v6 is set up.

      "1".A = "159.146.61.20";
      # "1".AAAA = "2a02:ff0:3d0e:ca89::53"; # TODO: Uncomment once public v6 is set up.
    };

    # CONTENT
    # TODO: Hickory does not support mixing classes in a zone.
    # xn--67-lubb0090b.HINFO = withClass "CH" {
    #   cpu = "Tendril";
    #   os = "hey, hater";
    # };
  };

  commonModules.authoritative =
    {
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) reverseList singleton;
      inherit (lib.strings) concatStringsSep;
    in
    {
      system.services.authoritative = {
        imports = singleton self.serviceModules.hickory-dns;

        hickory-dns = {
          package = mkPackage { inherit pkgs lib; };
          tomlFormat = pkgs.formats.toml { };

          settings = {
            listen_addrs_ipv4 = singleton "0.0.0.0";
            listen_addrs_ipv6 = singleton "::";
            listen_port = 53;

            zones = singleton {
              zone = "${apex.FQDN |> reverseList |> concatStringsSep "."}.";
              zone_type = "Primary";
              axfr_policy = "AllowAll";
              file = pkgs.writeText "zone" apex.RENDERED;
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

  commonModules.resolver =
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
        imports = singleton self.serviceModules.hickory-dns;

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
              stores.options.validate = true;
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

  flake.darwinModules.networking = self.darwinModules.resolver;
  flake.darwinModules.resolver =
    { lib, pkgs, ... }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.attrsets) getLib;
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkBefore;

      bind = pkgs.callPackage (
        { stdenv, writeText }:
        stdenv.mkDerivation {
          pname = "resolver-bind-interpose";
          version = "1.0.0";

          src = writeText "bind.c" /* c */ ''
            #include <arpa/inet.h>
            #include <net/if.h>
            #include <netinet/in.h>
            #include <string.h>
            #include <sys/socket.h>

            static struct in6_addr __resolver_addr(void) {
              struct in6_addr addr;
              inet_pton(AF_INET6, "${address}", &addr);
              return addr;
            }

            static void __pin_to_loopback(int fd, const struct sockaddr *addr, socklen_t len) {
              if (addr == NULL || addr->sa_family != AF_INET6 || len != sizeof(struct sockaddr_in6))
                return;

              struct in6_addr resolver_addr = __resolver_addr();
              if (memcmp(&((const struct sockaddr_in6 *)addr)->sin6_addr, &resolver_addr, sizeof(resolver_addr)) != 0)
                return;

              unsigned int index = if_nametoindex("lo0");
              if (index == 0)
                return;

              setsockopt(fd, IPPROTO_IPV6, IPV6_BOUND_IF, &index, sizeof(index));
            }

            static int __bind_replacement(int fd, const struct sockaddr *addr, socklen_t len) {
              __pin_to_loopback(fd, addr, len);
              return bind(fd, addr, len);
            }

            __attribute__((used)) static struct {
              const void *replacement;
              const void *replacee;
            } _bind_replacement __attribute__((section("__DATA,__interpose"))) = {
              .replacement = (const void *)&__bind_replacement,
              .replacee = (const void *)&bind,
            };
          '';

          dontUnpack = true;
          dontConfigure = true;

          buildPhase = /* bash */ ''
            $CC -dynamiclib -Wall -o libbind.dylib $src
          '';

          installPhase = /* bash */ ''
            mkdir -p $out/lib
            install -m755 libbind.dylib $out/lib/
          '';
        }
      ) { };
    in
    {
      # When the DNS server is at a v6 address and NOT "::1", MacOS will ignore
      # it if we are on a v4-only network, because it assumes any v6 address not
      # loopback itself require WAN reachability. It performs no actual reachability
      # checks, and if it did, it would see that our ULA address is bound to `lo`, and
      # we would not need to perform such a horrible, terrifyingly despicable hack.
      imports = singleton {
        networking.dns = singleton "::1";
        system.services.resolver.hickory-dns.settings.listen_addrs_ipv6 = singleton "::1";
      };

      networking.dns = singleton address;

      launchd.daemons.resolver-autorestart = {
        serviceConfig.LaunchEvents."com.apple.notifyd.matching".network-change.Notification =
          "com.apple.system.config.network_change";

        command = pkgs.writers.writeNu "resolver-autorestart" /* nu */ ''
          def main [] {
            let probe = ^${getExe pkgs.dig} +time=1 +tries=1 @${address} $"(random chars --length 12).rgbcu.be" | complete

            if $probe.exit_code != 0 or $probe.stdout !~ "status: (NOERROR|NXDOMAIN)" {
              ^/bin/launchctl kickstart -k system/org.nixos.resolver
            }
          }
        '';
      };

      system.services.resolver.launchd.ProgramArguments =
        mkBefore
        <| singleton "${pkgs.writers.writeNu "resolver-setup" /* nu */ ''
          def --wrapped main [...arguments] {
            try { ^/sbin/ifconfig lo0 inet6 ${address}/128 alias }
            $env.DYLD_INSERT_LIBRARIES = "${getLib bind}/lib/libbind.dylib"

            # dyld deletes DYLD_* when loading the platform /bin/sh in argv[0], so run it with nixpkgs bash instead.
            exec ${getExe pkgs.bash} ...($arguments | skip 1)
          }
        ''}";
    };

  flake.nixosModules.networking = self.nixosModules.resolver;
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
