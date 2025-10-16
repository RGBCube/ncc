{
  darwinModules.hostname =
    { config, ... }:
    {
      system.defaults.smb = {
        NetBIOSName = config.networking.hostName;
        ServerDescription = config.networking.hostName;
      };
    };
}
