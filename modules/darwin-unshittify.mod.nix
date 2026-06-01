{
  flake.darwinModules.unshittify =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.modules) mkAfter;
      inherit (lib.shell) asShell;

      shadowPath = "/Users/${config.system.primaryUser}/.local/share/shadow";
    in
    {
      # SHADOW-XCODE
      system.activationScripts.script.text = mkAfter ''
        ${config.system.activationScripts.shadow-xcode.text}
      '';
      system.activationScripts.shadow-xcode.text = asShell pkgs.nushell "shadow-xcode.nu" /* nu */ ''
        use std null_device

        print "shadowing xcode..."

        let shadow_path = r##'${shadowPath}'##
        let original_size = ls /usr/bin/SplitForks | get 0.size

        let shadoweds = ls /usr/bin
        | flatten
        | where {
          $in.size == $original_size and (try {
            open $null_device | ^$in.name out+err>| str contains "xcode-select: note: No developer tools were found, requesting install."
          } catch {
            false
          })
        }
        | get name
        | each { path basename }

        rm -rf $shadow_path
        mkdir $shadow_path

        for shadowed in $shadoweds {
          ln --symbolic /usr/bin/false ($shadow_path | path join $shadowed)
        }
      '';

      # LOGIN WINDOW
      system.defaults.loginwindow = {
        DisableConsoleAccess = true;
        GuestEnabled = false;
      };

      # SCREENSAVER PASSWORD
      system.defaults.CustomSystemPreferences."com.apple.screensaver" = {
        askForPassword = 1;
        askForPasswordDelay = 0;
      };

      # CLOUD SAVES
      system.defaults.NSGlobalDomain.NSDocumentSaveNewDocumentsToCloud = false;

      # QUARANTINE
      system.defaults.LaunchServices.LSQuarantine = false;

      # AUTO-UPDATE
      system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;

      # AD TRACKING
      system.defaults.CustomSystemPreferences."com.apple.AdLib" = {
        allowApplePersonalizedAdvertising = false;
        allowIdentifierForAdvertising = false;
        forceLimitAdTracking = true;
        personalizedAdsMigrated = false;
      };
    };

  flake.homeModules.shadow-xcode =
    {
      config,
      lib,
      osConfig,
      ...
    }:
    let
      inherit (lib.strings) optionalString;

      shadowPath = "${config.xdg.data.directory}/shadow";
    in
    {
      assertions = [
        {
          assertion =
            !osConfig.nixpkgs.hostPlatform.isDarwin || shadowPath == "${config.directory}/.local/share/shadow";
          message = "shadow-xcode: XDG_DATA_HOME drifted from the hardcoded path in darwinModules.unshittify";
        }
      ];

      programs.nushell.extraConfig =
        # For some reason mkIf does not work here.
        optionalString osConfig.nixpkgs.hostPlatform.isDarwin
        <| /* nu */ ''
          do --env {
            let usr_bin_index = $env.PATH
            | enumerate
            | where item == /usr/bin
            | get 0.index;

            $env.PATH = $env.PATH
            | insert $usr_bin_index "${shadowPath}";
          }
        '';
    };
}
