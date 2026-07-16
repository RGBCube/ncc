{ self, ... }:
{
  flake.darwinModules.default = self.darwinModules.hostname;
  flake.darwinModules.hostname =
    { config, ... }:
    {
      system.defaults.smb = {
        NetBIOSName = config.networking.hostName;
        ServerDescription = config.networking.hostName;
      };
    };
}
