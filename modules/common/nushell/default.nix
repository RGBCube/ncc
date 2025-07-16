{ config, lib, pkgs, ... }: let
  inherit (lib) attrValues const enabled getExe mapAttrs mkIf optionalAttrs readFile removeAttrs replaceString;
in {
  environment = optionalAttrs config.isLinux {
    sessionVariables.SHELLS = getExe pkgs.nushell;
  } // {
    shells = mkIf config.isDarwin [ pkgs.nushell ];

    shellAliases = {
      la  = "ls --all";
      ll  = "ls --long";
      lla = "ls --long --all";
      sl  = "ls";

      cp = "cp --recursive --verbose --progress";
      mk = "mkdir";
      mv = "mv --verbose";
      rm = "rm --recursive --verbose";

      pstree = "pstree -g 3";
      tree   = "eza --tree --git-ignore --group-directories-first";
    };

    systemPackages = attrValues {
      inherit (pkgs)
        carapace      # For completions.
        fish          # For completions.
        zsh           # For completions.
        inshellisense # For completions.

        zoxide   # For better cd.
      ;
    };
  };

  home-manager.sharedModules = [(homeArgs: let
    homeConfig = homeArgs.config;
  in {
    xdg.configFile = {
      "nushell/carapace.nu".source = pkgs.runCommand "carapace.nu" {} ''
        ${getExe pkgs.carapace} _carapace nushell > $out
      '';

      "nushell/zoxide.nu".source = pkgs.runCommand "zoxide.nu" {} ''
        ${getExe pkgs.zoxide} init nushell --cmd cd > $out
      '';

      "nushell/ls_colors.txt".source = pkgs.runCommand "ls_colors.txt" {} ''
        ${getExe pkgs.vivid} generate gruvbox-dark-hard > $out
      '';
    };

    programs.direnv = enabled {
      nix-direnv = enabled;

      enableNushellIntegration = true;
    };

    programs.nushell = enabled {
      configFile.text = readFile ./config.nu;
      envFile.text    = readFile ./environment.nu;

      environmentVariables = let
        environmentVariables = config.environment.variables;

        homeVariables      = homeConfig.home.sessionVariables;
        # homeVariablesExtra = pkgs.runCommand "home-variables-extra.env" {} ''
        #     alias export=echo
        #     # echo foo > $out
        #     # FIXME
        #     eval $(cat ${homeConfig.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh) > $out
        #   ''
        #     # |> (aaa: (_: break _) aaa)
        #     |> readFile
        #     |> splitString "\n"
        #     |> filter (s: s != "")
        #     |> map (match "([^=]+)=(.*)")
        #     |> map (keyAndValue: nameValuePair (first keyAndValue) (last keyAndValue))
        #     |> foldl' (x: y: x // y) {};
        homeVariablesExtra = {};
      in environmentVariables // homeVariables // homeVariablesExtra
        |> mapAttrs (const <| replaceString "$HOME" homeConfig.home.homeDirectory);

      shellAliases = removeAttrs config.environment.shellAliases [ "ls" "l" ] // {
        cdtmp = "cd (mktemp --directory)";
      };
    };
  })];
}
