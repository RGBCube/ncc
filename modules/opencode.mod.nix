{
  flake.homeModules.opencode =
    { lib, pkgs, ... }:
    let
      inherit (lib.strings) toJSON;
    in
    {
      packages = [
        pkgs.opencode
      ];

      xdg.config.file."opencode/opencode.json".text = toJSON {
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

          bash = {
            "jj diff*" = "allow";
            "jj evolog*" = "allow";
            "jj help*" = "allow";
            "jj interdiff*" = "allow";
            "jj log*" = "allow";
            "jj root*" = "allow";
            "jj show*" = "allow";
            "jj status*" = "allow";
            "jj st*" = "allow";
            "jj version*" = "allow";
            "jj bookmark list*" = "allow";
            "jj config get*" = "allow";
            "jj config list*" = "allow";
            "jj config path*" = "allow";
            "jj file annotate*" = "allow";
            "jj file list*" = "allow";
            "jj file search*" = "allow";
            "jj file show*" = "allow";
            "jj git remote list*" = "allow";
            "jj git root*" = "allow";
            "jj git colocation status*" = "allow";
            "jj operation diff*" = "allow";
            "jj operation log*" = "allow";
            "jj operation show*" = "allow";
            "jj op diff*" = "allow";
            "jj op log*" = "allow";
            "jj op show*" = "allow";
            "jj sparse list*" = "allow";
            "jj tag list*" = "allow";
            "jj util completion*" = "allow";
            "jj util config-schema*" = "allow";
            "jj util markdown-help*" = "allow";
            "jj workspace list*" = "allow";
            "jj workspace root*" = "allow";
          };
        };

        autoupdate = false;
      };
    };
}
