{ config, lib, ... }: let
  inherit (lib) genAttrs mkConst mkIf remove;
in {
  options.services.restic.hosts = mkConst <| remove config.networking.hostName [ "nine" "best" ];

  config.secrets.resticPassword.file = mkIf config.isServer ./password.age;

  config.services.restic.backups =  mkIf config.isServer <| genAttrs config.services.restic.hosts (host: {
    repository   = "sftp:backup@${host}:${config.networking.hostName}-backup";
    passwordFile = config.secrets.resticPassword.path;
    initialize   = true;

    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 3"
    ];
  });
}

