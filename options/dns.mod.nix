{ lib, ... }:
let
  inherit (lib.fixedPoints) fix;
  inherit (lib.attrsets)
    attrByPath
    attrNames
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
  inherit (lib.trivial) id warnIf throwIf;
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
    raw
    str
    submodule
    ;
  inherit (lib.types.dns) name rrset;

  quote = value: ''"${escape [ ''"'' "\\" ] value}"'';

  weight =
    flag: bit:
    if !flag then
      0
    else if bit == 0 then
      1
    else
      2 * weight flag (bit - 1);

  types.plural =
    element:
    coercedTo (
      addCheck raw (value: value != [ ] && element.check value)
      // {
        inherit (element) description;
      }
    ) singleton (listOf element);

  mkField =
    rest: type: description:
    mkOption (rest // { inherit type description; });

  mkStringRecord =
    {
      plural ? true,
      rdata ? id,
    }:
    description:
    mkOption {
      type = rrset <| (if plural then types.plural else nullOr) str;
      default = if plural then [ ] else null;
      inherit description;
    }
    // {
      _plural = plural;
      _rdata = rdata;
    };

  mkNameRecord =
    {
      plural ? true,
      rdata ? name.render,
    }:
    description:
    mkOption {
      type = rrset <| (if plural then types.plural else nullOr) name;
      default = if plural then [ ] else null;
      inherit description;
    }
    // {
      _plural = plural;
      _rdata = rdata;
    };

  mkAttrRecord =
    {
      plural ? true,
    }:
    description: options: rdata:
    mkOption {
      inherit description;
      type = rrset <| (if plural then types.plural else nullOr) <| submodule { inherit options; };
      default = if plural then [ ] else null;
    }
    // {
      _plural = plural;
      _rdata = rdata;
    };

  node = submodule (
    { config, options, ... }:
    fix (self: {
      # Child labels are lowercase, so an uppercase label here is a typo'd or
      # unsupported record type (like AAA) rather than a subdomain.
      freeformType =
        addCheck (lazyAttrsOf node) (
          children: children |> attrNames |> all (label: match ".*[A-Z].*" label == null)
        )
        // {
          description = "DNS name trie with lowercase labels";
        };

      options.A = mkStringRecord { } "IPv4 Address record.";

      options.AAAA = mkStringRecord { } "IPv6 Address record.";

      options.ANAME = mkNameRecord { plural = false; } "Address-specific DNS aliases.";

      options.CAA =
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

      options.CERT =
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

      options.CNAME = mkNameRecord { plural = false; } "Canonical name record.";

      options.CSYNC =
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

      options.DS =
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

      options.HINFO = mkAttrRecord { } "Host information." {
        cpu = mkField { } str "A character-string which specifies the CPU type.";
        os = mkField { } str "A character-string which specifies the operating system type.";
      } (self: "${quote self.cpu} ${quote self.os}");

      options.HTTPS = self.options.SVCB;

      options.MX = mkAttrRecord { } "Mail exchange record." {
        preference =
          mkField { } ints.u16
            "A 16 bit integer which specifies the preference given to this RR among others at the same owner. Lower values are preferred.";
        exchange =
          mkField { } name
            "A domain-name which specifies a host willing to act as a mail exchange for the owner name.";
      } (self: "${toString self.preference} ${name.render self.exchange}");

      options.NAPTR =
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
              mkField { } name
                "A domain-name which is the next domain-name to query for depending on the potential values found in the flags field.";
          }
          (
            self:
            "${toString self.order} ${toString self.preference} ${quote self.flags} ${quote self.services} ${quote self.regexp} ${name.render self.replacement}"
          );

      options.NS = mkNameRecord { } "Name server record.";

      options.OPENPGPKEY = mkStringRecord { } "OpenPGP public key.";

      options.PTR = mkNameRecord { } "Pointer record.";

      options.SMIMEA = self.options.TLSA;

      options.SOA =
        mkAttrRecord { plural = false; } "Start of [a zone of] authority record."
          {
            mname =
              mkField { } name
                "The domain-name of the name server that was the original or primary source of data for this zone.";
            rname =
              mkField { } name
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
            "${name.render self.mname} ${name.render self.rname} ${toString self.serial} ${self.refresh} ${self.retry} ${self.expire} ${self.minimum}"
          );

      options.SRV =
        mkAttrRecord { } "Service locator."
          {
            priority = mkField { } ints.u16 "The priority of this target host.";
            weight =
              mkField { } ints.u16
                "A server selection mechanism. The weight field specifies a relative weight for entries with the same priority.";
            port = mkField { } ints.u16 "The port on this target host of this service.";
            target = mkField { } name "The domain name of the target host.";
          }
          (
            self:
            "${toString self.priority} ${toString self.weight} ${toString self.port} ${name.render self.target}"
          );

      options.SSHFP = mkAttrRecord { } "SSH Public Key Fingerprint." {
        algorithm = mkField { } ints.u8 "The SSH public key algorithm.";
        fingerprintType = mkField { } ints.u8 "The fingerprint type to use.";
        fingerprint = mkField { } str "The fingerprint of the public key.";
      } (self: "${toString self.algorithm} ${toString self.fingerprintType} ${self.fingerprint}");

      options.SVCB =
        mkAttrRecord { } "DNS SVCB and HTTPS RRs."
          {
            priority =
              mkField { } ints.u16
                "When SvcPriority is 0 the SVCB record is in AliasMode. Otherwise, it is in ServiceMode.";
            target =
              mkField { } name
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
              (name.render self.target)
            ]
            ++ (
              self.parameters
              |> mapAttrsToList (
                key: value:
                "${key}=${
                  toList value
                  |> map toString
                  |> concatStringsSep ","
                  |> quote
                }"
              )
            )
            |> concatStringsSep " "
          );

      options.TLSA = mkAttrRecord { } "Certificate association." {
        usage =
          mkField { } ints.u8
            "Specifies the provided association that will be used to match the certificate presented in the TLS handshake.";
        selector =
          mkField { } ints.u8
            "Specifies which part of the TLS certificate presented by the server will be matched against the association data.";
        matching = mkField { } ints.u8 "Specifies how the certificate association is presented.";
        data = mkField { } str "Binary data for validating the cert.";
      } (self: "${toString self.usage} ${toString self.selector} ${toString self.matching} ${self.data}");

      options.TXT = mkStringRecord {
        rdata =
          value:
          value
          # A character-string holds at most 255 bytes, longer values are carried as
          # multiple character-strings in one record. Readers join them back together.
          |> fix (
            chunk: rest:
            if stringLength rest <= 255 then
              singleton rest
            else
              singleton (substring 0 255 rest) ++ chunk (substring 255 (stringLength rest - 255) rest)
          )
          |> map quote
          |> concatStringsSep " ";
      } "Text record.";

      options.FQDN = mkOption {
        readOnly = true;
        type = name;
        description = "The absolute DNS name of this node as a root-first label path.";
        # This option tree is mounted at `flake.dns`, drop that prefix after dropping `FQDN`.
        default = options.FQDN.loc |> init |> drop 2;
      };

      options.RECORDS = mkOption {
        readOnly = true;
        type =
          listOf
          <| submodule {
            imports = (rrset str).getSubModules;

            options.owner = mkField { } name "The absolute owner name as a root-first label path.";
            options.type = mkField { } str "The DNS record type.";
          };
        description = "Every record owned by this node.";
        default =
          config
          |> filterAttrs (optionName: _: options ? ${optionName}._rdata)
          |> mapAttrsToList (
            type: rrset:
            (
              if options.${type}._plural then
                rrset.rdata
              else if rrset.rdata != null then
                singleton rrset.rdata
              else
                [ ]
            )
            |> map (rdata: {
              owner = config.FQDN;
              inherit type;

              inherit (rrset) class ttl;
              rdata = options.${type}._rdata rdata;
            })
          )
          |> concatLists
          |> (
            records:
            # A CNAME forbids any other data at its name.
            if config.CNAME.rdata != null && length records > 1 then
              throw "The name ${name.render config.FQDN} declares a CNAME record next to other records."
            else
              records
          );
      };

      options.ZONE_RECORDS = mkOption {
        readOnly = true;
        type = self.options.RECORDS.type;
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
                  if childNode.SOA.rdata == null then
                    walk childNode
                    ++ optionals (childNode.NS.rdata != [ ]) (childNode.RECORDS |> filter (entry: entry.type == "DS"))
                  else
                    # childNode is a new zone. This expression is for records to the parent,
                    # so only take the parts required for delegation. Which are NS records
                    # and A/AAAA of the targets of those NS records.

                    # All NS and DS records
                    (childNode.RECORDS |> filter (entry: entry.type == "NS" || entry.type == "DS"))

                    # All NS records' A and AAAA contents.
                    ++ (
                      childNode.NS.rdata
                      |> concatMap (
                        nsName:
                        # Only if ns contents are in-bailiwick.
                        optionals (take (length childNode.FQDN) nsName == childNode.FQDN) (
                          (childNode |> attrByPath (nsName |> drop (length childNode.FQDN)) { }).RECORDS or [ ]
                          |> filter ({ type, ... }: type == "A" || type == "AAAA")
                          |> (
                            glue:
                            # Without glue this delegation can never resolve, its
                            # addresses are only reachable through the delegation itself.
                            if glue == [ ] then
                              throw "The in-bailiwick name server ${name.render nsName} of the delegated zone ${name.render childNode.FQDN} has no A or AAAA records to use as glue."
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
          walk config
          |> warnIf (
            config.SOA.rdata == null
          ) "records of zone '${name.render config.FQDN}' which does not declare an authority were evaluated"
          |> throwIf (
            config.SOA.rdata != null && config.NS.rdata == [ ]
          ) "zone '${name.render config.FQDN}' declares a SOA but no NS records.";
      };

      options.ZONE_RECORDS_RENDERED = mkOption {
        readOnly = true;
        type = nullOr str;
        description = "The BIND zone file body for this zone, null when this node does not define a SOA.";
        default =
          config.ZONE_RECORDS
          |> map (
            entry: "${name.render entry.owner} ${entry.ttl} ${entry.class} ${entry.type} ${entry.rdata}"
          )
          |> concatLines;
      };
    })
  );
in
{
  options.flake.dns = mkOption {
    type = node;
    default = { };
    # TODO: description.
  };
}
