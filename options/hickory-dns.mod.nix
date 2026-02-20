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
            "/bin/sh"
            "-c"
            /* bash */ ''
              /bin/wait4path /nix/store && exec ${getExe' cfg.package "hickory-dns"} --config ${cfg.configFile}
            ''
          ];
          KeepAlive = true;
          RunAtLoad = true;
        };
      };
    };
}
