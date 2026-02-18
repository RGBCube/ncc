let
  inherit (builtins)
    attrNames
    concatMap
    elem
    filter
    foldl'
    listToAttrs
    readDir
    readFileType
    ;

  singleton = value: [ value ];
  optional = condition: consequence: if condition then [ consequence ] else [ ];
  uniq = list: list |> foldl' (acc: item: if elem item acc then acc else acc ++ singleton item) [ ];

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
        value.publicKeys = uniq <| optional (keys ? ${host}) keys.${host} ++ keys.admins;
      })
    );

  moduleSecrets =
    listFilesRecursive "modules" ./modules
    |> filter isAge
    |> map (path: {
      name = path;
      value.publicKeys = uniq <| keys.all;
    });
in
listToAttrs (hostSecrets ++ moduleSecrets)
// {
  "bootstrap.age".publicKeys = keys.all;
}
