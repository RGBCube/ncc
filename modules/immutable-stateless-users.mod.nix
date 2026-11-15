{ self, ... }:
{
  flake.nixosModules.default = self.nixosModules.immutable-users;
  flake.nixosModules.immutable-users =
    { config, lib, ... }:
    let
      inherit (lib.attrsets) filterAttrs mapAttrsToList getAttr;
      inherit (lib.lists) concatLists;
      inherit (lib.trivial) const;
    in
    {
      users.mutableUsers = false;

      users.users = {
        nm-iodine.uid = 551;
        nscd.uid = 552;
        sshd.uid = 553;
        systemd-oom.uid = 554;
      };

      users.groups = {
        nscd.gid = config.users.users.nscd.uid;
        polkituser.gid = config.users.users.polkituser.uid;
        sshd.gid = config.users.users.sshd.uid;
        systemd-coredump.gid = config.users.users.systemd-coredump.uid;
        systemd-oom.gid = config.users.users.systemd-oom.uid;
      };

      environment.etc."shells".enable = false;

      assertions =
        [ ]
        ++ (
          config.users.users
          |> filterAttrs (const <| getAttr "enable")
          |> mapAttrsToList (
            name: user: [
              {
                assertion = user.uid != null;
                message = "`users.users.${name}.uid` must be set to avoid stateful UID allocation.";
              }
              {
                assertion = !user.autoSubUidGidRange;
                message = "`users.users.${name}.autoSubUidGidRange` must be false, declare subUidRanges and subGidRanges.";
              }
            ]
          )
          |> concatLists
        )
        ++ (
          config.users.groups
          |> mapAttrsToList (
            name: group: {
              assertion = group.gid != null;
              message = "`users.groups.${name}.gid` must be set to avoid stateful GID allocation.";
            }
          )
        );
    };
}
