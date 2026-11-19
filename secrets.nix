let
  inherit (builtins)
    attrNames
    attrValues
    concatLists
    concatMap
    elem
    filter
    foldl'
    getAttr
    listToAttrs
    mapAttrs
    match
    readDir
    readFileType
    ;

  singleton = value: [ value ];
  optional = condition: consequence: if condition then [ consequence ] else [ ];
  uniq = list: list |> foldl' (acc: item: if elem item acc then acc else acc ++ singleton item) [ ];
  mapAttrsToList = function: attrs: mapAttrs function attrs |> attrValues;
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
    getAttr (readFileType directory) {
      regular = singleton base;
      directory =
        readDir directory
        |> mapAttrsToList (
          name: type:
          getAttr type {
            directory = listFilesRecursive "${base}/${name}" /${directory}/${name};
            regular = singleton "${base}/${name}";
          }
        )
        |> concatLists;
    };

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
