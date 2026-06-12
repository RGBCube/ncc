{ self }:
let
  inherit (self.lists) all reverseList;
  inherit (self.strings) concatStringsSep match;
  inherit (self.types) addCheck listOf str;
  inherit (self.types.dns) label;

  rrset =
    value:
    if value._type or "" == "rrset" then
      value
    else
      {
        _type = "rrset";
        rdata = value;
      };
in
{

  dns.withTtl = ttl: value: rrset value // { inherit ttl; };
  dns.withClass = class: value: rrset value // { inherit class; };

  types.dns.label =
    addCheck str (
      label: match "(\\*|[A-Za-z0-9_]|[A-Za-z0-9_][A-Za-z0-9_-]{0,61}[A-Za-z0-9_])" label != null
    )
    // {
      description = "DNS label";
    };

  # Names are stored as absolute, root-first label paths. Root is [ ].
  types.dns.name =
    addCheck (listOf label)
      # Check inner items eagerly rather than lazily.
      (labels: labels |> all label.check)
    // {
      description = "DNS name as a root-first label path";
      render = labels: "${labels |> reverseList |> concatStringsSep "."}.";
    };

}
