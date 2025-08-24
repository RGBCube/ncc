{ lib, ... }: let
  # inherit (lib) enabled;
  inherit (lib.strings) toJSON;

  allBasic = map (x: x // { type = "basic"; });

  isBuiltIn = {
    type        = "device_if";
    identifiers = [{
      is_built_in_keyboard = true;
    }];
  };

  isTurkish = {
    type          = "input_source_if";
    input_sources = [{
      language = "tr";
    }];
  };

  simple_modifications = [
    {
      from.key_code = "caps_lock";

      to = [{ key_code = "escape"; }];
    }

    {
      from.key_code = "escape";

      to = [{ key_code = "caps_lock"; }];
    }
  ];

  complex_modifications.rules = [
    {
      description  = "Replace alt+spacebar with spacebar";
      manipulators = allBasic [
        {
          from.key_code            = "spacebar";
          from.modifiers.mandatory = [ "option" ];
          from.modifiers.optional  = [ "shift" "control" "command" "fn" ];

          to = [{ key_code = "spacebar"; }];

          conditions = [ isBuiltIn ];
        }
      ];
    }

    {
      description  = "Swap ĞğüÜ and {[]}";
      manipulators = allBasic [
        { # ğ -> [
          from.key_code           = "open_bracket";
          from.modifiers.optional = [ "control" "command" "fn" ];

          to = [{
            key_code  = "8";
            modifiers = [ "right_option" ];
          }];

          conditions = [ isBuiltIn isTurkish ];
        }
        { # Ğ -> {
          from.key_code            = "open_bracket";
          from.modifiers.mandatory = [ "shift" ];
          from.modifiers.optional  = [ "control" "option" "command" "fn" ];

          to = [{
            key_code  = "7";
            modifiers = [ "right_option" ];
          }];

          conditions = [ isBuiltIn isTurkish ];
        }
        { # ü -> ]
          from.key_code           = "close_bracket";
          from.modifiers.optional = [ "control" "command" "fn" ];

          to = [{
            key_code  = "9";
            modifiers = [ "right_option" ];
          }];

          conditions = [ isBuiltIn isTurkish ];
        }
        { # Ü -> }
          from.key_code            = "close_bracket";
          from.modifiers.mandatory = [ "shift" ];
          from.modifiers.optional  = [ "control" "option" "command" "fn" ];

          to = [{
            key_code  = "0";
            modifiers = [ "right_option" ];
          }];

          conditions = [ isBuiltIn isTurkish ];
        }
        { # [ -> ğ
          from.key_code            = "8";
          from.modifiers.mandatory = [ "option" ];
          from.modifiers.optional  = [ "control" "command" "fn" ];

          to = [{ key_code = "open_bracket"; }];

          conditions = [ isBuiltIn isTurkish ];
        }
        { # { -> Ğ
          from.key_code            = "7";
          from.modifiers.mandatory = [ "option" ];
          from.modifiers.optional  = [ "control" "command" "fn" ];

          to = [{
            key_code  = "open_bracket";
            modifiers = [ "shift" ];
          }];

          conditions = [ isBuiltIn isTurkish ];
        }
        { # ] -> ü
          from.key_code            = "9";
          from.modifiers.mandatory = [ "option" ];
          from.modifiers.optional  = [ "control" "command" "fn" ];

          to = [{ key_code = "close_bracket"; }];

          conditions = [ isBuiltIn isTurkish ];
        }
        { # } -> Ü
          from.key_code            = "0";
          from.modifiers.mandatory = [ "option" ];
          from.modifiers.optional  = [ "control" "command" "fn" ];

          to = [{
            key_code  = "close_bracket";
            modifiers = [ "shift" ];
          }];

          conditions = [ isBuiltIn isTurkish ];
        }
      ];
    }

    {
      description = "Swap ı and i";
      manipulators = allBasic [
        { # ı -> i
          from.key_code           = "quote";
          from.modifiers.optional = [ "control" "option" "command" "fn" ];

          to = [{ key_code = "i"; }];

          conditions = [ isBuiltIn isTurkish ];
        }
        { # i -> ı
          from.key_code           = "i";
          from.modifiers.optional = [ "control" "option" "command" "fn" ];

          to = [{ key_code = "quote"; }];

          conditions = [ isBuiltIn isTurkish ];
        }
      ];
    }
  ];
in {
  homebrew.casks = [ "karabiner-elements" ];

  home-manager.sharedModules = [{
    xdg.configFile."karabiner/karabiner.json".text = toJSON {
      global.show_in_menu_bar = false;

      profiles = [{
        inherit complex_modifications;

        name     = "Default";
        selected = true;

        virtual_hid_keyboard.keyboard_type_v2 = "ansi";

        devices = [{
          inherit simple_modifications;

          identifiers.is_keyboard = true;
        }];
      }];
    };
  }];
}
