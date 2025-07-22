{ pkgs, ... }: let
  package = pkgs.python314;
in {
  environmennt.variables = {
    UV_PYTHON_PREFERENCE = "system";
    UV_PYTHON = "${package}";
  };

  environment.systemPackages = [
    package
    pkgs.uv
  ];
}
