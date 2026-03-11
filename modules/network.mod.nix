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

  flake.homeModules.wifi-alias =
    { osConfig, pkgs, ... }:
    let
      showPasswordDarwin = pkgs.writeShellScript "show-password" ''
        echo "You really thought, didn't you! TODO"
        exit 1
      '';

      showPasswordLinux = "${pkgs.networkmanager}/bin/nmcli dev wifi show-password";
    in
    {
      programs.nushell.aliases.wifi =
        if osConfig.nixpkgs.hostPlatform.isLinux then
          showPasswordLinux
        else if osConfig.nixpkgs.hostPlatform.isDarwin then
          showPasswordDarwin
        else
          throw "Unsupported OS";
    };

  flake.nixosModules.network =
    { config, lib, ... }:
    let
      inherit (lib.attrsets) attrNames filterAttrs getAttr;
      inherit (lib.lists) map;
      inherit (lib.modules) mkAfter mkDefault;
      inherit (lib.strings) concatStringsSep optionalString replaceStrings;
      inherit (lib.trivial) const;
    in
    {
      networking.useNetworkd = true;

      networking.nftables.enable = true;

      networking.networkmanager.enable = true;

      users.extraGroups.networkmanager.members =
        config.users.users |> filterAttrs (const <| getAttr "isNormalUser") |> attrNames;

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
