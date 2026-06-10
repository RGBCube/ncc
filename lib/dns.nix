_:
let
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
  withTtl = ttl: value: rrset value // { inherit ttl; };
  withClass = class: value: rrset value // { inherit class; };
}
