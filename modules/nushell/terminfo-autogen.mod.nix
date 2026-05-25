{
  flake.homeModules.terminfo-autogen =
    { pkgs, lib, ... }:
    let
      inherit (lib.meta) getExe';

      tic = getExe' pkgs.ncurses "tic";

      terminfo-autogen = pkgs.writeTextDir "terminfo-autogen.nu" /* nu */ ''
        const CAPABILITIES = {
          TN: meta,

          am: bool, bce: bool, ccc: bool, eo: bool, hs: bool, km: bool, mc5i: bool, mir: bool,
          msgr: bool, npc: bool, xenl: bool, AX: bool, Tc: bool, Su: bool, XT: bool, fullkbd: bool,

          colors: num, cols: num, it: num, lines: num, pairs: num,

          acsc: str, bel: str, blink: str, bold: str, cbt: str, civis: str, clear: str, cnorm: str,
          cr: str, csr: str, cub: str, cub1: str, cud: str, cud1: str, cuf: str, cuf1: str, cup: str,
          cuu: str, cuu1: str, cvvis: str, dch: str, dch1: str, dim: str, dl: str, dl1: str, dsl: str,
          ech: str, ed: str, el: str, el1: str, flash: str, fsl: str, home: str, hpa: str, ht: str,
          hts: str, ich: str, ich1: str, il: str, il1: str, ind: str, indn: str, initc: str, invis: str,
          is2: str, kb2: str, mc0: str, mc4: str, mc5: str, meml: str, memu: str, nel: str, oc: str,
          op: str, rc: str, rep: str, rev: str, ri: str, rin: str, ritm: str, rmacs: str, rmam: str,
          rmcup: str, rmir: str, rmkx: str, rmm: str, rmso: str, rmul: str, rmxx: str, rs1: str,
          rs2: str, sc: str, setab: str, setaf: str, setrgbb: str, setrgbf: str, sgr: str, sgr0: str,
          sitm: str, smacs: str, smam: str, smcup: str, smir: str, smkx: str, smm: str, smso: str,
          smul: str, smxx: str, tbc: str, tsl: str, u6: str, u7: str, u8: str, u9: str, vpa: str,
          Ss: str, Se: str, Ms: str, Cs: str, Cr: str, Smulx: str, Setulc: str, Sync: str, BD: str,
          BE: str, PS: str, PE: str, XM: str, xm: str, RV: str, rv: str, XR: str, xr: str, Enmg: str,
          Dsmg: str, Clmg: str, Cmg: str, E3: str, fe: str, fd: str, kxIN: str, kxOUT: str, kbs: str,
          kcbt: str, kcub1: str, kcud1: str, kcuf1: str, kcuu1: str, kdch1: str, kend: str, kent: str,
          kind: str, kri: str,

          kf1: str, kf2: str, kf3: str, kf4: str, kf5: str, kf6: str, kf7: str, kf8: str, kf9: str,
          kf10: str, kf11: str, kf12: str, kf13: str, kf14: str, kf15: str, kf16: str, kf17: str,
          kf18: str, kf19: str, kf20: str, kf21: str, kf22: str, kf23: str, kf24: str, kf25: str,
          kf26: str, kf27: str, kf28: str, kf29: str, kf30: str, kf31: str, kf32: str, kf33: str,
          kf34: str, kf35: str, kf36: str, kf37: str, kf38: str, kf39: str, kf40: str, kf41: str,
          kf42: str, kf43: str, kf44: str, kf45: str, kf46: str, kf47: str, kf48: str, kf49: str,
          kf50: str, kf51: str, kf52: str, kf53: str, kf54: str, kf55: str, kf56: str, kf57: str,
          kf58: str, kf59: str, kf60: str, kf61: str, kf62: str, kf63: str,

          khome: str, kich1: str, kmous: str, knp: str, kpp: str,

          kDC: str, kDC3: str, kDC4: str, kDC5: str, kDC6: str, kDC7: str, kDN: str, kDN3: str,
          kDN4: str, kDN5: str, kDN6: str, kDN7: str, kEND: str, kEND3: str, kEND4: str, kEND5: str,
          kEND6: str, kEND7: str, kHOM: str, kHOM3: str, kHOM4: str, kHOM5: str, kHOM6: str, kHOM7: str,

          kIC: str, kIC3: str, kIC4: str, kIC5: str, kIC6: str, kIC7: str,

          kLFT: str, kLFT3: str, kLFT4: str, kLFT5: str, kLFT6: str, kLFT7: str,

          kNXT: str, kNXT3: str, kNXT4: str, kNXT5: str, kNXT6: str, kNXT7: str,

          kPRV: str, kPRV3: str, kPRV4: str, kPRV5: str, kPRV6: str, kPRV7: str,

          kRIT: str, kRIT3: str, kRIT4: str, kRIT5: str, kRIT6: str, kRIT7: str,

          kUP: str, kUP3: str, kUP4: str, kUP5: str, kUP6: str, kUP7: str,
        }

        def xtgettcap [capabilities: list<string>]: nothing -> record {
          # XTGETTCAP returns a separate DCS response (\eP1+r...\e\\) per capability,
          # so term query's --terminator \e\\ would stop after the first one and the
          # rest would print to the terminal.
          #
          # Append a DSR query (\e[5n) as sentinel — its response (\e[0n) can't appear
          # in DCS hex data, giving us a reliable terminator for the entire batch.
          term query $"\eP+q($capabilities | each { encode utf-8 | encode hex --lower } | str join ';')\e\\\e[5n" --terminator "\e[0n"
          | decode utf-8
          | split row "\e\\"
          | each { parse --regex '1\+r(?P<entry>.+)' | get 0?.entry? }
          | where { is-not-empty }
          | each {|entry|
            try {
              match ($entry | split row "=" --number 2) {
                [$key, $value] => { name: ($key | decode hex | decode utf-8), value: ($value | decode hex | decode utf-8) }
                [$key] => { name: ($key | decode hex | decode utf-8), value: true }
              }
            } catch { null }
          }
          | where { $in != null }
          | transpose --header-row --as-record
        }

        def terminfo-escape []: string -> string {
          split chars
          | each {|character|
            match $character {
              "\e" => '\E'
              "\u{7f}" => '^?'
              $c if $c < ' ' => $"^(char --integer (($c | encode utf-8 | into int) + 64))"
              _ => $character
            }
          }
          | str join
        }

        def build-terminfo-source [name: string, capabilities: record]: nothing -> string {
          let supported = $capabilities | columns

          $CAPABILITIES
          | items {|name, type|
            if $name not-in $supported { return }
            match $type {
              bool => $name
              num => $"($name)#($capabilities | get $name)"
              str => $"($name)=($capabilities | get $name | terminfo-escape)"
            }
          }
          | where { is-not-empty }
          | prepend $"($name)|auto-generated from XTGETTCAP"
          | str join ","
          | $in + ","
        }

        export def --env main [] {
          let directory = $env.XDG_DATA_HOME? | default ($env.HOME | path join ".local" "share") | path join "terminfo"

          let name = xtgettcap [TN] | get --optional TN
          if ($name | is-empty) { return }

          match (try { (date now) - (ls ($directory | path join ($name | split chars | first) $name) | get 0.modified) > 6hr }) {
            # Version older than 6h or doesn't exist.
            true | null => {
              let capabilities = xtgettcap ($CAPABILITIES | reject TN | columns)

              mkdir $directory
              build-terminfo-source $name $capabilities | ^${tic} -x -o $directory -

              hide-env --ignore-errors TERMINFO_DIRS TERMINFO TERM
              $env.TERMINFO = $directory
              $env.TERM = $name
            }

            # Version older than 6h or doesn't exist.
            false => {
              hide-env --ignore-errors TERMINFO_DIRS TERMINFO
              $env.TERMINFO = $directory
            }
          }
        }
      '';
    in
    {
      programs.nushell.extraConfig = # nu
        ''
          use ${terminfo-autogen}/terminfo-autogen.nu
          # try { terminfo-autogen } # FIXME: Works later but not in-config
        '';
    };
}
