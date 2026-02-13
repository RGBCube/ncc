{
  flake.homeModules.network-tools =
    { pkgs, ... }:
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
      inherit (lib.trivial) const;
    in
    {
      networking.useNetworkd = true;

      networking.nftables.enable = true;

      networking.networkmanager.enable = true;

      users.extraGroups.networkmanager.members =
        config.users.users |> filterAttrs (const <| getAttr "isNormalUser") |> attrNames;
    };
}
