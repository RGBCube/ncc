{
  homeModules.network-tools =
    { pkgs, ... }:
    {
      packages = [
        (pkgs.curl.override {
          gnutlsSupport = false;
          opensslSupport = false;
          wolfsslSupport = false;
          rustlsSupport = true;

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
          wihtNativeTls = false; # Use rustls.
        })

        pkgs.dig
        pkgs.doggo

        pkgs.dublin-traceroute
      ];
    };
}
