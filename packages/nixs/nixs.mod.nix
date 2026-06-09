{ lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      inherit (lib.meta) getExe;
    in
    {
      packages.nixs = pkgs.writeScriptBin "nixs" /* nu */ ''
        #!${getExe pkgs.nushell}
        #

        def is-denied [ ]: string -> bool {
          let argument = $in

          let exact = [
            "--arg-from-file"
            "--arg-from-stdin"
            "--commit-lock-file"
            "--debugger"
            "--eval-store"
            "--file"
            "--impure"
            "--include"
            "--inputs-from"
            "--option"
            "--output-lock-file"
            "--override-flake"
            "--override-input"
            "--recreate-lock-file"
            "--reference-lock-file"
            "--repair"
            "--store"
            "--to"
            "--update-input"
            "--write-to"
            "-I"
            "-f"
          ]

          let prefixes = $exact | each {|argument|
            if ($argument | str starts-with "--") {
              $"($argument)="
            } else {
              $argument
            }
          }

          ($argument in $exact) or ($prefixes | any {|prefix| $argument | str starts-with $prefix })
        }

        def --wrapped main [...args] {
          let arguments = match $args {
            ["--version"] => ["--version"]
            ["help", ..$rest] => ["help", ...$rest]
            ["config", "show", ..$rest] => ["config", "show", ...$rest]
            ["eval", ..$rest] => ["eval", "--read-only", ...$rest]
            ["registry", "list"] => ["registry", "list"]
            ["flake", "archive", ..$rest] => ["flake", "archive", "--no-write-lock-file", ...$rest]
            ["flake", "metadata", ..$rest] => ["flake", "metadata", "--no-write-lock-file", ...$rest]
            ["flake", "show", ..$rest] => ["flake", "show", "--no-write-lock-file", ...$rest]
            ["store", "info"] => ["store", "info"]
            ["path-info", ..$rest] => ["path-info", ...$rest]
            _ => {
              print --stderr $"unsupported command: ($args | str join ' ')"
              exit 64
            }
          }

          let denied = $arguments | where { is-denied }
          if ($denied | is-not-empty) {
            print --stderr $"denied arguments: ($denied | str join ', ')"
            exit 2
          }

          exec ${getExe pkgs.nix} --option allow-import-from-derivation false ...$arguments
        }
      '';
    };
}
