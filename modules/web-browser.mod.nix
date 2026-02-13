{ inputs, lib, ... }:
let
  inherit (lib) fix;
  inherit (lib.attrsets) attrNames mapAttrsToList;
  inherit (lib.lists)
    elem
    filter
    singleton
    ;
  inherit (lib.trivial) importJSON;
  inherit (lib.strings) hasInfix;

  extensions = {
    clearurls.id = "lckanjgmijmafbedllaakclkaicjfmnk";
    dark-reader.id = "eimadpbcbfnmbkopoojfekhnkhdbieeh";
    dearrow.id = "enamippconapkdmgfgjchkhakpfinmaj";
    floccus.id = "fnaicdffflnofjppbagibeoednhnbjhg";
    i-still-dont-care-about-cookies.id = "edibdbjcniadpccecjdfdjjppcpchdlm";
    kagi.id = "cdglnehniifkbagbbombnjghhcihifij";
    old-reddit-redirect.id = "dneaehbmnbhcippjikoajpoabadpodje";
    refined-github.id = "hlepfoohegkhhmjieoechaddaejaokhf";
    sponsorblock.id = "mnjggcdmjocbbbhaepdhchncahnbgone";
    stylus.id = "clngdbkpkpeebahjckkjfobafhncgmne";
    ublock-origin = fix (self: {
      id = "cjpalhdlnbpafiamejdnhcphjbkeiagm";

      filters.internal = attrNames <| importJSON "${inputs.ublock}/assets/assets.json";

      filters.wanted = [
        "user-filters"
        "ublock-filters"
        "ublock-badware"
        "ublock-privacy"
        "ublock-abuse"
        "ublock-unbreak"
        "easylist"
        "easyprivacy"
        "urlhaus-1"
        "plowe-0"

        "https://raw.githubusercontent.com/DandelionSprout/adfilt/refs/heads/master/ClearURLs%20for%20uBo/clear_urls_uboified.txt"
        "https://raw.githubusercontent.com/yokoffing/filterlists/refs/heads/main/privacy_essentials.txt"
        "https://raw.githubusercontent.com/DandelionSprout/adfilt/refs/heads/master/LegitimateURLShortener.txt"
        "https://raw.githubusercontent.com/yokoffing/filterlists/refs/heads/main/annoyance_list.txt"
        "https://raw.githubusercontent.com/DandelionSprout/adfilt/refs/heads/master/BrowseWebsitesWithoutLoggingIn.txt"
      ];

      filters.warnings =
        self.filters.wanted
        # Not external and not in internal list.
        |> filter (name: !(hasInfix "://" name || elem name self.filters.internal))
        |> map (invalid: "helium: unknown ublock filter list: ${invalid}");
    });
    vimium-c.id = "hfjbmagddngcpeloejdejnfgbamkjaeg";
    violentmonkey.id = "jinjaccalgkegednnccohejagnlnfdag";
    web-archives.id = "hkligngkgcpcolhcnkgccglchdafcnao";
  };

  policy = {
    # EXTENSIONS
    ExtensionInstallForcelist =
      extensions |> mapAttrsToList (_name: { id, ... }: "${id};https://services.helium.imput.net/ext");
    ExtensionInstallAllowlist = extensions |> mapAttrsToList (_name: { id, ... }: id);
    ExtensionInstallSources = singleton "https://services.helium.imput.net/*";

    # UBLOCK ORIGIN
    "3rdparty".extensions.${extensions.ublock-origin.id}.toOverwrite.filterLists =
      extensions.ublock-origin.filters.wanted;

    # # Setting the policy to False stops Chrome from ever checking if
    # # it's the default and turns user controls off for this option.
    # DefaultBrowserSettingEnabled = true;

    # SEARCH
    DefaultSearchProviderEnabled = true;
    DefaultSearchProviderName = "Kagi";
    DefaultSearchProviderSearchURL = "https://kagi.com/search?q={searchTerms}";
    DefaultSearchProviderSuggestURL = "https://kagi.com/api/autosuggest?q={searchTerms}";
    SearchSuggestEnabled = true;
  };
in
{
  flake.darwinModules.helium =
    { config, lib, ... }:
    let
      inherit (lib.generators) toPlist;
      inherit (lib.modules) mkAfter;

      managedPolicyPlist = toPlist { escape = true; } policy;
    in
    {
      inherit (extensions.ublock-origin.filters) warnings;

      system.activationScripts.script.text = mkAfter ''
        ${config.system.activationScripts.helium.text}
      '';
      system.activationScripts.helium.text = /* bash */ ''
        echo "setting up helium policy..."
        /usr/bin/install -d -m 755 "/Library/Managed Preferences"
        /bin/cat > "/Library/Managed Preferences/net.imput.helium.plist" <<'PLIST_EOF'
        ${managedPolicyPlist}
        PLIST_EOF
        /usr/sbin/chown root:wheel "/Library/Managed Preferences/net.imput.helium.plist"
        /bin/chmod 0644 "/Library/Managed Preferences/net.imput.helium.plist"
      '';
    };

  flake.nixosModules.helium =
    { lib, ... }:
    let
      inherit (lib.strings) toJSON;
    in
    {
      inherit (extensions.ublock-origin.filters) warnings;

      environment.etc."chromium/policies/managed/policies.json".text = toJSON policy;
    };

  flake.homeModules.helium =
    {
      lib,
      osConfig,
      ...
    }:
    let
      inherit (lib.lists) singleton;
    in
    {
      inherit (extensions.ublock-origin.filters) warnings;

      environment.sessionVariables.BROWSER = "helium";

      packages = singleton inputs.helium.packages.${osConfig.nixpkgs.hostPlatform.system}.default;
    };
}
