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
          wolfsslSupport = false;
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

  flake.homeModules.wifi-alias = { };

  flake.nixosModules.network =
    { config, lib, ... }:
    let
      inherit (lib.lists) map;
      inherit (lib.modules) mkAfter mkDefault;
      inherit (lib.strings) concatStringsSep optionalString replaceStrings;
    in
    {
      networking.useNetworkd = true;

      networking.nftables.enable = true;

      networking.wireless.enable = false;
      networking.wireless.iwd.enable = true;
      networking.wireless.iwd.settings.Settings.AutoConnect = true;

      secrets.wifiHome = {
        file = ./home.psk.age;
        owner = "root";
        mode = "0400";
      };

      systemd.tmpfiles.rules = [
        "d /var/lib/iwd 0700 root root -"
        "C /var/lib/iwd/PALA.psk 0600 root root - ${config.secrets.wifiHome.path}"
      ];

      services.zapret = {
        enable = true;

        # This configures iptables, we use ntfables.
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
            fib daddr type != local and meta mark & $desync_mark == 0 and tcp dport 443 queue num ${toString config.services.zapret.qnum} bypass

          ${optionalString config.services.zapret.httpSupport ''
            fib daddr type != local and meta mark & $desync_mark == 0 and tcp dport 80 queue num ${toString config.services.zapret.qnum} bypass
          ''}

          ${optionalString config.services.zapret.udpSupport ''
            fib daddr type != local and meta mark & $desync_mark == 0 and udp dport { ${
              config.services.zapret.udpPorts
              |> map (port: replaceStrings [ ":" ] [ "-" ] port)
              |> concatStringsSep ", "
            } } queue num ${toString config.services.zapret.qnum} bypass
          ''}
          }
        }
      '';
    };
}
