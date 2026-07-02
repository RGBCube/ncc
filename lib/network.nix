{ self }:
let
  inherit (self.strings) hasInfix hasPrefix match;
in
{
  network.isLoopback = address: match "127\\..*|::1|fd.*" address != null;

  network.isAddressV6 = address: hasInfix ":" address;
  network.isAddressV4 = address: !hasInfix ":" address;

  network.isSocketAddressV6 = address: hasPrefix "[" address;
  network.isSocketAddressV4 = address: !hasPrefix "[" address;

  network.familyOf = address: if match "\\[.*|.*:.*:.*" address != null then "v6" else "v4";
}
