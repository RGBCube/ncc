{ lib, ... }: let
  inherit (lib.strings) toJSON;
in {
  homebrew.casks = [ "maccy" ];

  system.defaults.CustomSystemPreferences."org.p0deje.Maccy" = {
    KeyboardShortcuts_delete = 0;
    KeyboardShortcuts_pin    = 0;
    KeyboardShortcuts_popup  = toJSON { carbonKeyCode = 9; carbonModifiers = 4352; }; # control+command+v

    SUEnableAutomaticChecks = 0;

    enabledPasteboardTypes = [
      "public.png"
      "public.file-url"
      "public.utf8-plain-text"
      "public.rtf"
      "public.tiff"
      "public.html"
    ];

    menuIcon      = "clipboard";
    popupPosition = "window";
    searchMode    = "fuzzy";

    showFooter = 0;
    showSearch = 1;
    showTitle  = 0;
  };
}
