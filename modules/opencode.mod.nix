{
  flake.homeModules.opencode =
    { lib, pkgs, ... }:
    let
      inherit (lib.generators) toJSON;
      inherit (lib.trivial) const flip;
      inherit (lib.attrsets) genAttrs;
    in
    {
      packages = [
        pkgs.opencode
      ];

      xdg.config.files."opencode/opencode.json".generator = toJSON { };
      xdg.config.files."opencode/opencode.json".value = {
        "$schema" = "https://opencode.ai/config.json";

        permission = {
          "*" = "ask";
          codesearch = "allow";
          glob = "allow";
          grep = "allow";
          list = "allow";
          lsp = "allow";
          read = "allow";
          task = "allow";
          todoread = "allow";
          todowrite = "allow";
          webfetch = "allow";
          websearch = "allow";

          bash = flip genAttrs (const "allow") [
            "rg*"
            "ls*"

            "jj bookmark list*"
            "jj config get*"
            "jj config list*"
            "jj config path*"
            "jj diff*"
            "jj evolog*"
            "jj file annotate*"
            "jj file list*"
            "jj file search*"
            "jj file show*"
            "jj git colocation status*"
            "jj git remote list*"
            "jj git root*"
            "jj help*"
            "jj interdiff*"
            "jj log*"
            "jj op diff*"
            "jj op log*"
            "jj op show*"
            "jj operation diff*"
            "jj operation log*"
            "jj operation show*"
            "jj resolve --list"
            "jj root*"
            "jj show*"
            "jj sparse list*"
            "jj st*"
            "jj status*"
            "jj tag list*"
            "jj util completion*"
            "jj util config-schema*"
            "jj util markdown-help*"
            "jj version*"
            "jj workspace list*"
            "jj workspace root*"

            "cargo clippy*"
            "cargo check*"
          ];
        };

        autoupdate = false;
      };
    };
}
