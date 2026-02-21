let
  allBasic = map (x: x // { type = "basic"; });

  isBuiltIn = {
    type = "device_if";
    identifiers = [
      { is_built_in_keyboard = true; }
    ];
  };

  isTurkish = {
    type = "input_source_if";
    input_sources = [
      { language = "tr"; }
    ];
  };

  simple_modifications = [
    {
      from.key_code = "caps_lock";
      to = [ { key_code = "escape"; } ];
    }
    {
      from.key_code = "escape";
      to = [ { key_code = "caps_lock"; } ];
    }
  ];

  complex_modifications.rules = [
    {
      description = "Replace alt+spacebar with spacebar";
      manipulators = allBasic [
        {
          from.key_code = "spacebar";
          from.modifiers.mandatory = [ "option" ];
          from.modifiers.optional = [
            "shift"
            "control"
            "command"
            "fn"
          ];

          to = [ { key_code = "spacebar"; } ];

          conditions = [ isBuiltIn ];
        }
      ];
    }

    {
      description = "Swap ğü and []";
      manipulators = allBasic [
        {
          # ğ -> [
          from.key_code = "open_bracket";
          from.modifiers.optional = [
            "control"
            "command"
            "fn"
          ];

          to = [
            {
              key_code = "8";
              modifiers = [ "right_option" ];
            }
          ];

          conditions = [
            isBuiltIn
            isTurkish
          ];
        }
        {
          # Ğ -> {
          from.key_code = "open_bracket";
          from.modifiers.mandatory = [ "shift" ];
          from.modifiers.optional = [
            "control"
            "option"
            "command"
            "fn"
          ];

          to = [
            {
              key_code = "7";
              modifiers = [ "right_option" ];
            }
          ];

          conditions = [
            isBuiltIn
            isTurkish
          ];
        }
        {
          # ü -> ]
          from.key_code = "close_bracket";
          from.modifiers.optional = [
            "control"
            "command"
            "fn"
          ];

          to = [
            {
              key_code = "9";
              modifiers = [ "right_option" ];
            }
          ];

          conditions = [
            isBuiltIn
            isTurkish
          ];
        }
        {
          # Ü -> }
          from.key_code = "close_bracket";
          from.modifiers.mandatory = [ "shift" ];
          from.modifiers.optional = [
            "control"
            "option"
            "command"
            "fn"
          ];

          to = [
            {
              key_code = "0";
              modifiers = [ "right_option" ];
            }
          ];

          conditions = [
            isBuiltIn
            isTurkish
          ];
        }
      ];
    }

    {
      description = "Swap ı and i";
      manipulators = allBasic [
        {
          from.key_code = "quote";
          from.modifiers.optional = [
            "control"
            "option"
            "command"
            "fn"
          ];

          to = [ { key_code = "i"; } ];

          conditions = [
            isBuiltIn
            isTurkish
          ];
        }
        {
          from.key_code = "i";
          from.modifiers.optional = [
            "control"
            "option"
            "command"
            "fn"
          ];

          to = [ { key_code = "quote"; } ];

          conditions = [
            isBuiltIn
            isTurkish
          ];
        }
      ];
    }
  ];
in
{ lib, ... }:
let
  inherit (lib.generators) toJSON;
in
{
  flake.darwinModules.keycode-remap =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      homebrew.casks = singleton "karabiner-elements";
    };

  flake.homeModules.keycode-remap =
    { lib, osConfig, ... }:
    let
      inherit (lib.modules) mkIf;
    in
    {
      xdg.config.files."karabiner/karabiner.json".generator =
        mkIf osConfig.nixpkgs.hostPlatform.isDarwin <| toJSON { };
      xdg.config.files."karabiner/karabiner.json".value = mkIf osConfig.nixpkgs.hostPlatform.isDarwin {
        global.show_in_menu_bar = false;

        profiles = [
          {
            inherit complex_modifications;

            name = "Default";
            selected = true;

            virtual_hid_keyboard.keyboard_type_v2 = "ansi";

            devices = [
              {
                inherit simple_modifications;

                identifiers.is_keyboard = true;
              }
            ];
          }
        ];
      };
    };
}
