{
  flake.homeModules.network-tools =
    {
      osConfig,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib.lists) optionals;
    in
    {
      packages = [
        (pkgs.curl.override {
          gnutlsSupport = false;
          opensslSupport = true; # OpenSSL supports QUIC.
          rustlsSupport = false;

          brotliSupport = true;
          zlibSupport = true;
          zstdSupport = true;

          c-aresSupport = true;

          http2Support = true;
          http3Support = true;

          gsaslSupport = true;

          idnSupport = true;
          ldapSupport = true;
          pslSupport = true;
          rtmpSupport = true;
          scpSupport = true;
          websocketSupport = true;
        })

        (pkgs.xh.override {
          withNativeTls = false; # Use rustls.
        })

        pkgs.dig
        pkgs.doggo
        pkgs.inetutils
      ]
      ++ optionals osConfig.nixpkgs.hostPlatform.isDarwin [
        pkgs.iproute2mac
      ];
    };

  flake.nixosModules.network =
    { config, lib, ... }:
    let
      inherit (lib.lists) map singleton;
      inherit (lib.modules) mkAfter mkDefault;
      inherit (lib.strings) concatStringsSep optionalString replaceStrings;
    in
    {
      secrets.wifiEnv = {
        file = ./password.env.age;
        owner = "root";
        mode = "0400";
      };

      persist.subvolumes = singleton "/var/lib/NetworkManager";

      networking.networkmanager = {
        enable = true;
        dns = "none";

        wifi.backend = "iwd";

        ensureProfiles.environmentFiles = singleton config.secrets.wifiEnv.path;
        ensureProfiles.profiles.home = {
          connection.id = "home";
          connection.type = "wifi";

          wifi.ssid = "PALA";
          wifi-security.key-mgmt = "wpa-psk";
          wifi-security.psk = "$WIFI_PSK";
        };
      };

      networking.nftables.enable = true;

      services.zapret = {
        enable = true;

        # This configures iptables, we use nftables.
        configureFirewall = false;

        # Troll packets on port 80 too.
        httpSupport = true;

        params = mkDefault [
          "--dpi-desync=fake,disorder2"
          "--dpi-desync-ttl=1"
          "--dpi-desync-autottl=2"
        ];
      };

      networking.nftables.ruleset = mkAfter /* nft */ ''
        table inet zapret {
          define desync_mark = 0x40000000

          chain postrouting {
            type filter hook postrouting priority mangle;
            policy accept;

            # Skip packets already handled by zapret (mark 0x40000000).
            fib daddr type != local \
            # Not marked by zapret.
            meta mark & $desync_mark == 0 \
            tcp dport 443 \
            queue num ${toString config.services.zapret.qnum} bypass;

          ${optionalString config.services.zapret.httpSupport ''
            fib daddr type != local \
            meta mark & $desync_mark == 0 \
            tcp dport 80 \
            queue num ${toString config.services.zapret.qnum} bypass;
          ''}

          ${optionalString config.services.zapret.udpSupport ''
            fib daddr type != local \
            meta mark & $desync_mark == 0 \
            udp dport { ${
              config.services.zapret.udpPorts |> map (replaceStrings [ ":" ] [ "-" ]) |> concatStringsSep ", "
            } } \
            queue num ${toString config.services.zapret.qnum} bypass;
          ''}
          }
        }
      '';
    };
}
