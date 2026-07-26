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
      inherit (lib.attrsets) genAttrs' nameValuePair;
      inherit (lib.lists) singleton;
      inherit (lib.modules) mkForce;
      inherit (lib.strings) makeBinPath;
      inherit (lib.trivial) flip;
    in
    {
      environment.systemPath = mkForce <| singleton <| makeBinPath config.environment.profiles;

      environment.systemPackages = [
        # darwin-rebuild depends on this.
        pkgs.gnugrep

        (pkgs.linkFarm "darwin-tools" (
          # /bin
          flip genAttrs' (name: nameValuePair "bin/${name}" "/bin/${name}") [
            "launchctl"
            "ps"
          ]
          # /usr/bin
          // flip genAttrs' (name: nameValuePair "bin/${name}" "/usr/bin/${name}") [
            "arch"
            "caffeinate"
            "defaults"
            "hdiutil"
            "log"
            "man"
            "open"
            "osascript"
            "pbcopy"
            "pbpaste"
            "plutil"
            "security"
            "sudo"
            "sw_vers"
            "xattr"
          ]
          # /usr/sbin
          // flip genAttrs' (name: nameValuePair "bin/${name}" "/usr/sbin/${name}") [
            "diskutil"
            "networksetup"
            "scutil"
            "softwareupdate"
            "sysctl"
            "system_profiler"
          ]
        ))
      ];
    };
}
