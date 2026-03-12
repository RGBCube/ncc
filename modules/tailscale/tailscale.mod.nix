let
  commonMagicDnsModule =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      services.hickory-dns.settings.zones = singleton {
        zone = "warthog-major.ts.net.";
        zone_type = "External";

        stores.type = "forward";
        stores.name_servers = singleton {
          socket_addr = "100.100.100.100:53";
          protocol = "udp";
          trust_negative_responses = true;
        };
      };
    };
in
{
  flake.nixosModules.tailscale =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkAfter mkIf;
    in
    {
      imports = [ commonMagicDnsModule ];

      secrets.tailscaleAuthKey = {
        file = ./tailscale.secret.age;
        owner = "root";
        mode = "0400";
      };

      services.tailscale = {
        enable = true;

        interfaceName = "ts0";
        useRoutingFeatures = "both";
        authKeyFile = config.secrets.tailscaleAuthKey.path;
        extraUpFlags = mkAfter [
          "--login-server=https://controlplane.tailscale.com"
          "--accept-dns=false" # hickory-dns handles DNS.
        ];
      };

      networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];

      # NFTABLES
      systemd.services.tailscaled.serviceConfig.Environment = mkIf config.networking.nftables.enable [
        "TS_DEBUG_FIREWALL_MODE=nftables"
      ];

      # UDP GRO FORWARDING OPTIMIZATION
      services.networkd-dispatcher = {
        enable = true;
        rules."50-tailscale-optimizations" = {
          onState = [ "routable" ];
          script = /* sh */ ''
            ${getExe pkgs.ethtool} --features ${config.networking.defaultGateway.interface} rx-udp-gro-forwarding on rx-gro-list off
          '';
        };
      };

      # WAIT-ONLINE
      systemd.network.wait-online.enable = false;
      boot.initrd.systemd.network.wait-online.enable = false;
    };

  flake.darwinModules.tailscale =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      imports = [ commonMagicDnsModule ];

      homebrew.casks = singleton "tailscale-app";
    };

  flake.homeModules.tailscale =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkIf;

      package = pkgs.tailscale;
    in
    {
      programs.nushell.aliases.ts =
        if osConfig.nixpkgs.hostPlatform.isDarwin then "tailscale" else getExe pkgs.tailscale;

      packages = mkIf osConfig.nixpkgs.hostPlatform.isLinux [
        package
      ];
    };
}
