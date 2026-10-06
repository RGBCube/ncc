{ self, ... }:
{
  perSystem =
    { lib, pkgs, ... }:
    let
      inherit (lib.attrsets) mapAttrs getAttr;
      inherit (lib.trivial) const;
      inherit (lib.meta) getExe;
      inherit (lib.strings) toJSON;
    in
    {
      packages.default = pkgs.writers.writeNuBin "default" /* nu */ ''
        def class-of [--host: string] {
          r###'${
            self.nixosConfigurations // self.darwinConfigurations
            |> mapAttrs (const <| getAttr "class")
            |> toJSON
          }'###
          | from json
          | get $host
        }

        def switch [--target: string, --pull-from: string, --toplevel: string] {
          let class = class-of --host $target

          let escalate = match $class {
            "nixos" => "run0"
            "darwin" => "sudo"
          }

          let activate = match $class {
            "nixos" => [$"($toplevel)/bin/switch-to-configuration" "switch"]
            "darwin" => [$"($toplevel)/activate"]
          }

          let prefix = if $pull_from == "auto" { [$escalate] } else { [ssh -t $target $escalate] }

          run-external ...[...$prefix nix copy --no-check-sigs --from $pull_from $toplevel]
          run-external ...[...$prefix dix /run/current-system $toplevel]
          run-external ...[...$prefix nix build --no-link --profile /nix/var/nix/profiles/system $toplevel]
          run-external ...[...$prefix ...$activate]
        }

        def main [] {
          help main
        }

        def "main deploy" [
          --eval-store: string = "auto"
          --store: string = "auto"
          host: string
        ] {
          let class = class-of --host $host

          let toplevel = (${getExe pkgs.nix-output-monitor} build
            --eval-store $eval_store
            --store $store
            --no-link
            --print-out-paths
            $"${self}#($class)Configurations.($host).config.system.build.toplevel"
            | str trim)

          switch --target $host --pull-from $store --toplevel $toplevel
        }

        def "main rollback" [
          --store: string = "auto"
          host: string
        ] {
          let generations = if $store == "auto" {
            ls /nix/var/nix/profiles
            | update name { path basename }
            | where ($it.name | str starts-with "system-")
            | select name modified
          } else {
            let names = (ssh $host ls /nix/var/nix/profiles
              | lines
              | where ($it | str starts-with "system-"))

            (ssh $host stat --format=%y ...($names | each { $"/nix/var/nix/profiles/($in)" })
              | lines
              | into datetime
              | wrap modified
              | merge ($names | wrap name))
          }

          let generation = ($generations
            | sort-by modified --reverse
            | each { $"($in.name)  ($in.modified)" }
            | input list
            | split row "  "
            | first)

          switch --target $host --pull-from $store --toplevel $"/nix/var/nix/profiles/($generation)"
        }
      '';
    };
}
