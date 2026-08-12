{ self }:
let
  inherit (self)
    attrNames
    isAttrs
    removeAttrs
    toJSON
    ;
  inherit (self.attrsets) mapAttrsToList;
  inherit (self.strings)
    concatLines
    concatStringsSep
    match
    replaceStrings
    stringLength
    ;
  inherit (self.lists)
    concatLists
    concatMap
    elem
    flatten
    optional
    singleton
    sortOn
    toList
    ;
in
{
  # KDL documents.
  generators.toKDL =
    {
      version,
      normalizeValueToNodeList ? singleton,
    }:
    let
      mkNode =
        {
          name,
          entries ? [ ],
          children ? [ ],
        }:
        {
          inherit name entries children;
        };

      attrsToNodeList =
        attrs:
        attrs
        |> mapAttrsToList (
          name: value:
          value
          |> toList
          |> concatMap normalizeValueToNodeList
          |> map (
            value:
            if isAttrs value then
              mkNode {
                inherit name;
                entries = value._ or [ ];
                children = attrsToNodeList <| removeAttrs value <| singleton "_";
              }
            else
              mkNode {
                inherit name;
                entries = singleton value;
              }
          )
        )
        |> concatLists;

      serialize.keywordPrefix =
        if version == 1 then
          ""
        else if version == 2 then
          "#"
        else
          throw "generators.toKDL: unsupported KDL version '${toString version}'";

      serialize.value =
        value:
        if value == true then
          "${serialize.keywordPrefix}true"
        else if value == false then
          "${serialize.keywordPrefix}false"
        else if value == null then
          "${serialize.keywordPrefix}null"
        else
          toJSON value;

      serialize.entry =
        entry:
        if isAttrs entry then
          mapAttrsToList (key: value: "${serialize.identifier key}=${serialize.value value}") entry
        else
          singleton <| serialize.value entry;

      serialize.identifier =
        identifier:
        if
          match "[A-Za-z_][A-Za-z0-9!$%&'*+.:?@^_|~-]*" identifier != null
          && !elem identifier [
            "true"
            "false"
            "null"
            "inf"
            "nan"
          ]
        then
          identifier
        else
          toJSON identifier;

      serialize.nodeToLines =
        {
          indent ? "",
        }:
        {
          name,
          entries,
          children,
        }:
        singleton "${indent}${
          singleton (serialize.identifier name)
          ++ concatMap serialize.entry entries
          ++ optional (children != [ ]) "{"
          |> concatStringsSep " "
        }"
        ++ concatMap (serialize.nodeToLines { indent = "${indent}    "; }) children
        ++ optional (children != [ ]) "${indent}}";
    in
    attrs:
    attrs
    |> attrsToNodeList
    |> concatMap (serialize.nodeToLines { })
    |> concatLines;

  # OpenSSH client config.
  generators.toSSHConfig =
    attrs:
    let
      render =
        value:
        if value == true then
          "yes"
        else if value == false then
          "no"
        else
          toString value;

      toLines =
        {
          indent ? "",
        }:
        attrs:
        attrs
        |> mapAttrsToList (name: value: toList value |> map (value: "${indent}${name} ${render value}"))
        |> flatten;
    in
    attrs
    |> attrNames
    # Plain options go first, as a section keyword claims the rest of the file.
    #
    # Host foo
    #     Bar baz
    # Biz fuz
    #
    # "Biz" is actually still a part of "Host foo". It's a footgun.
    |> sortOn (name: if !isAttrs attrs.${name} then -67 else 0)
    |> map (
      name:
      let
        value = attrs.${name};
      in
      if !isAttrs value then
        toLines { } { ${name} = value; }
      else
        value
        |> attrNames
        # Specific first, general last. "x.foo.com" must precede "*.foo.com".
        |> sortOn (pattern: -(stringLength <| replaceStrings [ "*" "?" ] [ "" "" ] pattern))
        |> map (pattern: singleton "${name} ${pattern}" ++ toLines { indent = "\t"; } value.${pattern})
        |> flatten
    )
    |> flatten
    |> concatLines;

  # lesskey(1) config format used by less.
  generators.toLesskey =
    sections:
    sections
    |> mapAttrsToList (
      section: entries:
      let
        separator = if section == "env" then " = " else " ";
      in
      singleton "#${section}"
      ++ mapAttrsToList (
        name: value: name + separator + (toList value |> map (value: "${value}") |> concatStringsSep " ")
      ) entries
    )
    |> flatten
    |> concatLines;
}
