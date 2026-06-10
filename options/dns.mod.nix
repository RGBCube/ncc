{ lib, ... }:
let
  inherit (lib.fixedPoints) fix;
  inherit (lib.attrsets)
    attrByPath
    filterAttrs
    mapAttrsToList
    ;
  inherit (lib.lists)
    all
    concatLists
    concatMap
    drop
    filter
    init
    length
    map
    optionals
    reverseList
    singleton
    take
    toList
    ;
  inherit (lib.options) mkOption;
  inherit (lib.strings)
    concatLines
    concatStringsSep
    escape
    match
    stringLength
    substring
    ;
  inherit (lib.trivial) id;
  inherit (lib.types)
    attrsOf
    addCheck
    bool
    coercedTo
    int
    ints
    lazyAttrsOf
    listOf
    nullOr
    oneOf
    str
    submodule
    ;

  quote = value: ''"${escape [ ''"'' "\\" ] value}"'';

  # A character-string holds at most 255 bytes, longer values are carried as
  # multiple character-strings in one record. Readers join them back together.
  chunk =
    value:
    if stringLength value <= 255 then
      singleton value
    else
      singleton (substring 0 255 value) ++ chunk (substring 255 (stringLength value - 255) value);

  # DNS names are stored as absolute, root-first label paths; the root is [ ].
  dnsLabel =
    addCheck str (
      label: match "(\\*|[A-Za-z0-9_]|[A-Za-z0-9_][A-Za-z0-9_-]{0,61}[A-Za-z0-9_])" label != null
    )
    // {
      description = "DNS label";
    };
  dnsName = addCheck (listOf str) (labels: all dnsLabel.check labels) // {
    description = "DNS name as a root-first label path";
  };
  dnsNames = coercedTo (
    addCheck dnsName (labels: labels != [ ])
    // {
      description = "non-root DNS name";
    }
  ) singleton (listOf dnsName);

  renderDnsName = labels: "${labels |> reverseList |> concatStringsSep "."}.";

  weight =
    flag: bit:
    if !flag then
      0
    else if bit == 0 then
      1
    else
      2 * weight flag (bit - 1);

  mkField =
    rest: type: description:
    mkOption (rest // { inherit type description; });

  mkStringRecord =
    {
      single ? false,
      _rdata ? id,
    }:
    description:
    mkOption {
      inherit description;
      type = if single then nullOr str else coercedTo str singleton (listOf str);
      default = if single then null else [ ];
    }
    // {
      _single = single;
      inherit _rdata;
    };

  mkDnsNameRecord =
    {
      single ? false,
    }:
    description:
    mkOption {
      inherit description;
      type = if single then nullOr dnsName else dnsNames;
      default = if single then null else [ ];
    }
    // {
      _single = single;
      _rdata = renderDnsName;
    };

  mkAttrRecord =
    {
      single ? false,
    }:
    description: options: _rdata:
    mkOption {
      inherit description;
      type = (if single then nullOr else listOf) <| submodule { inherit options; };
      default = if single then null else [ ];
    }
    // {
      _single = single;
      inherit _rdata;
    };

  record = submodule {
    options = {
      owner = mkField { } dnsName "The absolute owner name as a root-first label path.";
      type = mkField { } str "The DNS record type.";
      data = mkField { } str "The DNS record data.";
    };
  };

  dnsNode = submodule (
    { config, options, ... }:
    {
      freeformType = (lazyAttrsOf dnsNode) // {
        description = "DNS name trie";
      };

      options = fix (self: {
        A = mkStringRecord { } "IPv4 Address record.";

        AAAA = mkStringRecord { } "IPv6 Address record.";

        ANAME = mkDnsNameRecord { single = true; } "Address-specific DNS aliases.";

        CAA =
          mkAttrRecord { } "Certification Authority Authorization."
            {
              issuerCritical =
                mkField { } bool
                  "Indicates that the corresponding property tag MUST be understood if the semantics of the CAA record are to be correctly interpreted by an issuer.";
              reservedFlags =
                mkField { } (ints.between 0 127)
                  "The flags of the record minus the issuer critical flag.";
              tag = mkField { } str "The property tag.";
              value = mkField { } str "The raw value of the CAA record.";
            }
            (
              self:
              "${toString <| weight self.issuerCritical 7 + self.reservedFlags} ${self.tag} ${quote self.value}"
            );

        CERT =
          mkAttrRecord { } "Storing Certificates in the Domain Name System (DNS)."
            {
              type = mkField { } ints.u16 "The CERT type.";
              keyTag = mkField { } ints.u16 "The CERT key tag.";
              algorithm = mkField { } ints.u8 "The CERT algorithm.";
              certificate = mkField { } str "The CERT record data.";
            }
            (
              self: "${toString self.type} ${toString self.keyTag} ${toString self.algorithm} ${self.certificate}"
            );

        CNAME = mkDnsNameRecord { single = true; } "Canonical name record.";

        CSYNC =
          mkAttrRecord { } "Child-to-parent synchronization record."
            {
              serial = mkField { } ints.u32 "A copy of the 32-bit SOA serial number from the child zone.";
              immediate = mkField { } bool "The immediate flag.";
              soaMinimum = mkField { } bool "The soaminimum flag.";
              types =
                mkField { } (listOf str)
                  "Indicates the record types to be processed by the parental agent.";
            }
            (
              self:
              concatStringsSep " "
              <|
                [
                  (toString self.serial)
                  (toString <| weight self.immediate 0 + weight self.soaMinimum 1)
                ]
                ++ self.types
            );

        DS =
          mkAttrRecord { } "Delegation signer."
            {
              keyTag = mkField { } ints.u16 "Lists the key tag of the DNSKEY RR referred to by the DS record.";
              algorithm =
                mkField { } ints.u8
                  "Lists the algorithm number of the DNSKEY RR referred to by the DS record.";
              digestType = mkField { } ints.u8 "Identifies the algorithm used to construct the digest.";
              digest = mkField { } str "A digest of the DNSKEY RR referred to by the DS record.";
            }
            (
              self:
              "${toString self.keyTag} ${toString self.algorithm} ${toString self.digestType} ${self.digest}"
            );

        HINFO = mkAttrRecord { } "Host information." {
          cpu = mkField { } str "A character-string which specifies the CPU type.";
          os = mkField { } str "A character-string which specifies the operating system type.";
        } (self: "${quote self.cpu} ${quote self.os}");

        HTTPS = self.SVCB;

        MX = mkAttrRecord { } "Mail exchange record." {
          preference =
            mkField { } ints.u16
              "A 16 bit integer which specifies the preference given to this RR among others at the same owner. Lower values are preferred.";
          exchange =
            mkField { } dnsName
              "A domain-name which specifies a host willing to act as a mail exchange for the owner name.";
        } (self: "${toString self.preference} ${renderDnsName self.exchange}");

        NAPTR =
          mkAttrRecord { } "Naming Authority Pointer."
            {
              order =
                mkField { } ints.u16
                  "A 16-bit unsigned integer specifying the order in which the NAPTR records MUST be processed. The ordering is from lowest to highest.";
              preference =
                mkField { } ints.u16
                  "A 16-bit unsigned integer that specifies the order in which NAPTR records with equal Order values SHOULD be processed, low numbers being processed before high numbers.";
              flags =
                mkField { } str
                  "A character-string containing flags to control aspects of the rewriting and interpretation of the fields in the record.";
              services =
                mkField { } str
                  "A character-string that specifies the Service Parameters applicable to this delegation path.";
              regexp =
                mkField { } str
                  "A character-string containing a substitution expression that is applied to the original string held by the client in order to construct the next domain name to lookup.";
              replacement =
                mkField { } dnsName
                  "A domain-name which is the next domain-name to query for depending on the potential values found in the flags field.";
            }
            (
              self:
              "${toString self.order} ${toString self.preference} ${quote self.flags} ${quote self.services} ${quote self.regexp} ${renderDnsName self.replacement}"
            );

        NS = mkDnsNameRecord { } "Name server record.";

        OPENPGPKEY = mkStringRecord { } "OpenPGP public key.";

        PTR = mkDnsNameRecord { } "Pointer record.";

        SMIMEA = self.TLSA;

        SOA =
          mkAttrRecord { single = true; } "Start of [a zone of] authority record."
            {
              mname =
                mkField { } dnsName
                  "The domain-name of the name server that was the original or primary source of data for this zone.";
              rname =
                mkField { } dnsName
                  "A domain-name which specifies the mailbox of the person responsible for this zone.";
              serial =
                mkField { } ints.u32
                  "The unsigned 32 bit version number of the original copy of the zone.";
              refresh = mkField { } str "A 32 bit time interval before the zone should be refreshed.";
              retry =
                mkField { } str
                  "A 32 bit time interval that should elapse before a failed refresh should be retried.";
              expire =
                mkField { } str
                  "A 32 bit time value that specifies the upper limit on the time interval that can elapse before the zone is no longer authoritative.";
              minimum =
                mkField { } str
                  "The unsigned 32 bit minimum TTL field that should be exported with any RR from this zone.";
            }
            (
              self:
              "${renderDnsName self.mname} ${renderDnsName self.rname} ${toString self.serial} ${self.refresh} ${self.retry} ${self.expire} ${self.minimum}"
            );

        SRV =
          mkAttrRecord { } "Service locator."
            {
              priority = mkField { } ints.u16 "The priority of this target host.";
              weight =
                mkField { } ints.u16
                  "A server selection mechanism. The weight field specifies a relative weight for entries with the same priority.";
              port = mkField { } ints.u16 "The port on this target host of this service.";
              target = mkField { } dnsName "The domain name of the target host.";
            }
            (
              self:
              "${toString self.priority} ${toString self.weight} ${toString self.port} ${renderDnsName self.target}"
            );

        SSHFP = mkAttrRecord { } "SSH Public Key Fingerprint." {
          algorithm = mkField { } ints.u8 "The SSH public key algorithm.";
          fingerprintType = mkField { } ints.u8 "The fingerprint type to use.";
          fingerprint = mkField { } str "The fingerprint of the public key.";
        } (self: "${toString self.algorithm} ${toString self.fingerprintType} ${self.fingerprint}");

        SVCB =
          mkAttrRecord { } "DNS SVCB and HTTPS RRs."
            {
              priority =
                mkField { } ints.u16
                  "When SvcPriority is 0 the SVCB record is in AliasMode. Otherwise, it is in ServiceMode.";
              target =
                mkField { } dnsName
                  "The domain name of either the alias target (for AliasMode) or the alternative endpoint (for ServiceMode).";
              parameters = mkField { default = { }; } (
                attrsOf
                <| oneOf [
                  int
                  str
                  (listOf str)
                ]
              ) "A set of key=value pairs describing the alternative endpoint at TargetName.";
            }
            (
              self:
              [
                (toString self.priority)
                (renderDnsName self.target)
              ]
              ++ (
                self.parameters
                |> mapAttrsToList (
                  key: value: "${key}=${quote <| concatStringsSep "," <| map toString <| toList value}"
                )
              )
              |> concatStringsSep " "
            );

        TLSA = mkAttrRecord { } "Certificate association." {
          usage =
            mkField { } ints.u8
              "Specifies the provided association that will be used to match the certificate presented in the TLS handshake.";
          selector =
            mkField { } ints.u8
              "Specifies which part of the TLS certificate presented by the server will be matched against the association data.";
          matching = mkField { } ints.u8 "Specifies how the certificate association is presented.";
          data = mkField { } str "Binary data for validating the cert.";
        } (self: "${toString self.usage} ${toString self.selector} ${toString self.matching} ${self.data}");

        TXT = mkStringRecord {
          _rdata = value: value |> chunk |> map quote |> concatStringsSep " ";
        } "Text record.";

        FQDN = mkOption {
          internal = true;
          readOnly = true;
          type = dnsName;
          description = "The absolute DNS name of this node as a root-first label path.";
          # This option tree is mounted at `flake.dns`, drop that prefix after dropping `FQDN`.
          default = options.FQDN.loc |> init |> drop 2;
        };

        RECORDS = mkOption {
          internal = true;
          readOnly = true;
          type = listOf record;
          description = "Every record owned by this node.";
          default =
            config
            |> filterAttrs (optionName: _: options ? ${optionName}._rdata)
            |> mapAttrsToList (
              type: value:
              value
              |> (
                value:
                if value == null then
                  [ ]
                else if options.${type}._single then
                  singleton value
                else
                  toList value
              )
              |> map (value: {
                owner = config.FQDN;
                inherit type;
                data = options.${type}._rdata value;
              })
            )
            |> concatLists
            |> (
              records:
              # A CNAME forbids any other data at its name.
              if config.CNAME != null && length records > 1 then
                throw "The name ${renderDnsName config.FQDN} declares a CNAME record next to other records."
              else
                records
            );
        };

        ENTRIES = mkOption {
          internal = true;
          readOnly = true;
          type = listOf record;
          description = "Every record in this zone.";
          default =
            let
              walk =
                currentNode:
                (currentNode.RECORDS |> filter (entry: entry.type != "DS"))
                ++ (
                  currentNode
                  |> filterAttrs (optionName: _: !(options ? ${optionName}))
                  |> mapAttrsToList (
                    _: childNode:
                    if childNode.SOA == null then
                      walk childNode
                      ++ optionals (childNode.NS != [ ]) (childNode.RECORDS |> filter (entry: entry.type == "DS"))
                    else
                      # A zone cut. Only the delegation records and the addresses
                      # of in-bailiwick name servers (glue) cross into this zone.
                      (
                        # All NS and DS records
                        childNode.RECORDS |> filter (entry: entry.type == "NS" || entry.type == "DS")
                      )
                      ++ (
                        # All NS records' A and AAAA contents.
                        childNode.NS
                        |> concatMap (
                          nsName:
                          # Only if ns contents are in bailwick.
                          optionals (take (length childNode.FQDN) nsName == childNode.FQDN) (
                            (childNode |> attrByPath (nsName |> drop (length childNode.FQDN)) { }).RECORDS or [ ]
                            |> filter ({ type, ... }: type == "A" || type == "AAAA")
                            |> (
                              glue:
                              # Without glue this delegation can never resolve, its
                              # addresses are only reachable through the delegation itself.
                              if glue == [ ] then
                                throw "The in-bailiwick name server ${renderDnsName nsName} of the delegated zone ${renderDnsName childNode.FQDN} has no A or AAAA records to use as glue."
                              else
                                glue
                            )
                          )
                        )
                      )
                  )
                  |> concatLists
                );
            in
            if config.SOA == null then
              [ ]
            else if config.NS == [ ] then
              throw "The zone ${renderDnsName config.FQDN} declares a SOA but no NS records."
            else
              walk config;
        };

        RENDERED = mkOption {
          internal = true;
          readOnly = true;
          type = nullOr str;
          description = "The BIND zone file body for this zone, null when this node does not define a SOA.";
          default =
            if config.SOA == null then
              null
            else
              config.ENTRIES
              |> map (entry: "${renderDnsName entry.owner} ${entry.type} ${entry.data}")
              |> concatLines;
        };
      });
    }
  );
in
{
  options.flake.dns = mkOption {
    type = dnsNode;
    default = { };
    # TODO: description.
  };
}
