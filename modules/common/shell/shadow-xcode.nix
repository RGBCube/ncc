{ config, lib, pkgs, ... }: let
  inherit (lib) getExe mkAfter mkIf;
in {
  home-manager.sharedModules = mkIf config.isDarwin [(homeArgs: let
    config' = homeArgs.config;
    lib' = homeArgs.lib;

    inherit (lib'.hm.dag) entryAfter;

    # Replace with the command that has been triggering
    # the "install developer tools" popup.
    #
    # Set by default to "SplitForks" because who even uses that?
    originalTrigger = "/usr/bin/SplitForks";
    originalTriggerLiteral = ''"${originalTrigger}"'';

    # Where the symbolic links to `/usr/bin/false` will
    # be created in to shadow all popup-triggering binaries.
    #
    # Place this in your $env.PATH right before /usr/bin
    # to never get the "install developer tools" popup ever again:
    #
    # ```nu
    # let usr_bin_index = $env.PATH
    # | enumerate
    # | where item == /usr/bin
    # | get 0.index
    #
    # $env.PATH = $env.PATH | insert $usr_bin_index $shadow_path
    # ```
    #
    # Do NOT set this to a path that you use for other things,
    # it will get deleted if it exists to only have the shadowers.
    shadowPath = "${config'.home.homeDirectory}/.local/shadow"; # Did you read the comment?
    shadowPathLiteral = ''"${shadowPath}"'';
  in {
    home.activation.shadow = entryAfter [ "installPackages" "linkGeneration" ] /* bash */ ''
      ${getExe pkgs.nushell} ${pkgs.writeScript "shadow-xcode.nu" ''
        use std null_device

        let original_size = ls ${originalTriggerLiteral} | get 0.size

        let shadoweds = ls /usr/bin
        | flatten
        | where {
          # All xcode-select binaries are the same size, so we can narrow down and not run weird stuff.
          $in.size == $original_size and (try {
            open $null_device | ^$in.name out+err>| str contains "xcode-select: note: No developer tools were found, requesting install."
          } catch {
            # If it exited with a nonzero code, it's probably already set up.
            false
          })
        }
        | get name
        | each { path basename }

        rm -rf ${shadowPathLiteral}
        mkdir ${shadowPathLiteral}

        for shadowed in $shadoweds {
          ln --symbolic /usr/bin/false (${shadowPathLiteral} | path join $shadowed)
        }
      ''}
    '';

    programs.nushell.configFile.text = mkAfter /* nu */ ''
      do --env {
        let usr_bin_index = $env.PATH
        | enumerate
        | where item == /usr/bin
        | get 0.index;

        $env.PATH = $env.PATH
        | insert $usr_bin_index ${shadowPathLiteral};
      }
    '';
  })];
}
