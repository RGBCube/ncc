#!/usr/bin/env nu

# Rebuild a NixOS / Darwin config.
def main --wrapped [
  host: string = "" # The host to build.
  --remote          # Whether if this is a remote host. The config will be built on this host if it is.
  ...arguments      # The arguments to pass to `nh {os,darwin} switch` and `nix` (separated by --).
]: nothing -> nothing {
  let host = if ($host | is-not-empty) {
    if $host != (hostname) and not $remote {
      print $"(ansi yellow_bold)warn:(ansi reset) building local configuration for hostname that does not match the local machine"
    }

    $host
  } else if $remote {
    print $"(ansi red_bold)error:(ansi reset) hostname not specified for remote build"
    exit 1
  } else {
    (hostname)
  }

  if $remote {
    let files = jj --ignore-working-copy file list | complete
    if $files.exit_code != 0 {
      error make {msg: $files.stderr}
    }

    ssh -tt ("root@" + $host) "rm --recursive --force ncc"
    if $env.LAST_EXIT_CODE != 0 {
      error make {msg: "Failed to clear the remote configuration directory"}
    }

    $files.stdout | (rclone copy ./ :sftp:ncc
      --files-from-raw -
      --sftp-ssh $"ssh -o BatchMode=yes root@($host)"
      --progress)
    if $env.LAST_EXIT_CODE != 0 {
      error make {msg: "Failed to copy the configuration"}
    }

    ssh -tt ("root@" + $host) $"
      cd ncc
      nu ./rebuild.nu ($host) ($arguments | str join ' ')
    "

    exit $env.LAST_EXIT_CODE
  }

  let args_split = $arguments | prepend "" | split list "--"
  let nh_flags = [
    "--hostname" $host
  ] | append ($args_split | get 0 | where { $in != "" })

  let nix_flags = [
    "--accept-flake-config"
    "--extra-experimental-features" "pipe-operators"
  ] | append ($args_split | get --optional 1 | default [])

  if (uname | get kernel-name) == "Darwin" {
    nh darwin switch . ...$nh_flags -- ...$nix_flags
  } else {
    NH_BYPASS_ROOT_CHECK=true nh os switch . ...$nh_flags -- ...$nix_flags
  }
}
