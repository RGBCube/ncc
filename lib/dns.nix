{ self }:
let
  inherit (self.lists) all reverseList;
  inherit (self.strings) concatStringsSep match;
  inherit (self.options) mkOption;
  inherit (self.types)
    addCheck
    coercedTo
    enum
    listOf
    raw
    str
    submodule
    ;
  inherit (self.types.dns) label;
in
{
  types.dns.rrset =
    rdataType:
    coercedTo raw (
      value: if value._type or "" == "rrset" then removeAttrs value [ "_type" ] else { rdata = value; }
    )
    <| submodule {
      options.ttl = mkOption {
        type = str;
        default = "1h";
        description = "The time to live.";
      };
      options.class = mkOption {
        type = enum [
          "IN"
          "CH"
          "HS"
        ];
        default = "IN";
        description = "The DNS class.";
      };
      options.rdata = mkOption {
        type = rdataType;
        description = "The data.";
      };
    };

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
