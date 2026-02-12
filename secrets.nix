let
  inherit (builtins)
    attrNames
    concatMap
    elem
    filter
    hasAttr
    listToAttrs
    readDir
    ;

  keys = import ./keys.nix;

  # Recursively find all .age files under a directory, returning relative paths.
  findAgeFiles =
    base: dir:
    let
      entries = readDir dir;
      names = attrNames entries;
    in
    concatMap (
      name:
      let
        path = dir + "/${name}";
        rel = "${base}/${name}";
      in
      if entries.${name} == "directory" then
        findAgeFiles rel path
      else if entries.${name} == "regular" && builtins.match ".*\\.age$" name != null then
        [ rel ]
      else
        [ ]
    ) names;

  # Extract the host name from a relative path like "hosts/best/grafana/password.age".
  hostOf =
    path:
    let
      parts = builtins.split "/" path;
      # parts = [ "hosts" "/" "best" "/" ... ], host is at index 2.
    in
    builtins.elemAt parts 2;

  hostSecrets = concatMap (
    host:
    let
      paths = findAgeFiles "hosts/${host}" ./hosts/${host};
    in
    map (path: {
      name = path;
      value.publicKeys = (if hasAttr host keys then [ keys.${host} ] else [ ]) ++ keys.admins;
    }) paths
  ) (attrNames (readDir ./hosts));

  moduleSecrets =
    let
      paths = findAgeFiles "modules" ./modules;
    in
    map (path: {
      name = path;
      value.publicKeys = keys.all;
    }) paths;
in
listToAttrs (hostSecrets ++ moduleSecrets)
