let
  inherit (builtins)
    attrNames
    concatMap
    filter
    listToAttrs
    readDir
    ;

  singleton = value: [ value ];
  optional = condition: consequence: if condition then [ consequence ] else [ ];

  listFilesRecursive =
    base: directory:
    let
      entries = readDir directory;
      names = attrNames entries;
    in
    names
    |> concatMap (
      name:
      if entries.${name} == "directory" then
        listFilesRecursive "${base}/${name}" /${directory}/${name}
      else if entries.${name} == "regular" then
        singleton "${base}/${name}"
      else
        [ ]
    );

  isAge = name: builtins.match ".*\\.age$" name != null;

  keys = import ./keys.nix;

  hostSecrets =
    attrNames (readDir ./hosts)
    |> concatMap (
      host:
      listFilesRecursive "hosts/${host}" ./hosts/${host}
      |> filter isAge
      |> map (path: {
        name = path;
        value.publicKeys = optional (keys ? ${host}) keys.${host} ++ keys.admins;
      })
    );

  moduleSecrets =
    listFilesRecursive "modules" ./modules
    |> filter isAge
    |> map (path: {
      name = path;
      value.publicKeys = keys.all;
    });
in
listToAttrs (hostSecrets ++ moduleSecrets)
