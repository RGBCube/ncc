{ self, ... }:
{
  commonModules.system-path =
    { lib, ... }:
    let
      inherit (lib.modules) mkForce;
    in
    {
      environment.profiles = mkForce [
        "/etc/profiles/per-user/$USER"
        "/run/current-system/sw"
      ];
    };

  flake.nixosModules.default = self.nixosModules.system-path;

  flake.darwinModules.default = self.darwinModules.system-path;
  flake.darwinModules.system-path =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) mapAttrs' nameValuePair;
      inherit (lib.lists) singleton;
      inherit (lib.modules) mkForce;
      inherit (lib.strings) makeBinPath;
    in
    {
      environment.systemPath = mkForce <| singleton <| makeBinPath config.environment.profiles;

      environment.systemPackages = [
        # darwin-rebuild depends on this.
        pkgs.gnugrep

        (pkgs.linkFarm "darwin-tools" (
          {
            sudo = "/usr/bin/sudo";

            launchctl = "/bin/launchctl";
            ps = "/bin/ps";

            arch = "/usr/bin/arch";
            caffeinate = "/usr/bin/caffeinate";
            defaults = "/usr/bin/defaults";
            hdiutil = "/usr/bin/hdiutil";
            log = "/usr/bin/log";
            open = "/usr/bin/open";
            osascript = "/usr/bin/osascript";
            pbcopy = "/usr/bin/pbcopy";
            pbpaste = "/usr/bin/pbpaste";
            plutil = "/usr/bin/plutil";
            security = "/usr/bin/security";
            sw_vers = "/usr/bin/sw_vers";
            xattr = "/usr/bin/xattr";

            diskutil = "/usr/sbin/diskutil";
            networksetup = "/usr/sbin/networksetup";
            scutil = "/usr/sbin/scutil";
            softwareupdate = "/usr/sbin/softwareupdate";
            sysctl = "/usr/sbin/sysctl";
            system_profiler = "/usr/sbin/system_profiler";
          }
          |> mapAttrs' (name: nameValuePair "bin/${name}")
        ))
      ];
    };
}
