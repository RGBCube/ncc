{ self }:
let
  inherit (self) attrNames isAttrs;
  inherit (self.attrsets) mapAttrsToList;
  inherit (self.strings)
    concatLines
    concatStringsSep
    replaceStrings
    stringLength
    ;
  inherit (self.lists)
    flatten
    singleton
    sortOn
    toList
    ;
in
{
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

  # CLI flag config format used by ripgrep.
  # true -> --flag, string/int -> --flag<newline>value
  generators.toCliArgumentList =
    attrs:
    attrs
    |> mapAttrsToList (
      name: value:
      if value == true then
        singleton "--${name}"
      else
        [
          "--${name}"
          (toString value)
        ]
    )
    |> flatten
    |> concatLines;
}
