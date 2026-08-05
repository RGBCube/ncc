let
  inherit (builtins)
    attrNames
    attrValues
    concatMap
    elem
    filter
    foldl'
    listToAttrs
    mapAttrs
    match
    readDir
    readFileType
    ;

  singleton = value: [ value ];
  optional = condition: consequence: if condition then [ consequence ] else [ ];
  uniq = list: list |> foldl' (acc: item: if elem item acc then acc else acc ++ singleton item) [ ];

  filterAttrs =
    predicate: set:
    set
    |> attrNames
    |> filter (name: predicate name set.${name})
    |> map (name: {
      inherit name;
      value = set.${name};
    })
    |> listToAttrs;

  listFilesRecursive =
    base: directory:
    if readFileType directory != "directory" then
      singleton base
    else
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

  isAge = name: match ".*\\.age$" name != null;

  entitiesModule =
    (import ./modules/entities.mod.nix {
      self = entitiesModule;
      lib.attrsets = { inherit attrValues filterAttrs mapAttrs; };
    }).flake;

  inherit (entitiesModule) ssh-keys ssh-keys-admin;

  hostSecrets =
    attrNames (readDir ./hosts)
    |> concatMap (
      host:
      listFilesRecursive "hosts/${host}" ./hosts/${host}
      |> filter isAge
      |> map (path: {
        name = path;
        value.publicKeys = uniq <| optional (ssh-keys ? ${host}) ssh-keys.${host} ++ ssh-keys-admin;
      })
    );

  moduleSecrets =
    listFilesRecursive "modules" ./modules
    |> filter isAge
    |> map (path: {
      name = path;
      value.publicKeys = uniq <| attrValues ssh-keys;
    });
in
listToAttrs (hostSecrets ++ moduleSecrets)
// {
  "bootstrap.age".publicKeys = uniq <| attrValues ssh-keys;
}
