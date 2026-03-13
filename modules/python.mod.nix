{
  flake.homeModules.python =
    { pkgs, ... }:
    let
      package = pkgs.python3;
    in
    {
      environment.sessionVariables = {
        UV_PYTHON_PREFERENCE = "system";
        UV_PYTHON = "${package}";
      };

      packages = [
        package
        pkgs.uv
      ];
    };
}
