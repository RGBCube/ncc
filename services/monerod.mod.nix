{ self, ... }:
{
  flake.serviceModules.monerod =
    {
      config,
      lib,
      name,
      options,
      ...
    }:
    let
      inherit (lib.attrsets) filterAttrs getAttr;
      inherit (lib.generators) mkKeyValueDefault mkValueStringDefault toKeyValue;
      inherit (lib.lists)
        elemAt
        last
        map
        optional
        singleton
        ;
      inherit (lib.meta) getExe';
      inherit (lib.network) familyOf;
      inherit (lib.options) literalExpression mkOption;
      inherit (lib.strings)
        match
        splitString
        toInt
        typeOf
        ;
      inherit (lib.types)
        addCheck
        bool
        enum
        int
        ints
        listOf
        nullOr
        package
        path
        port
        str
        submodule
        ;

      cfg = config.monerod;
    in
    {
      imports = singleton self.serviceModules.base;

      options.monerod = {
        package = mkOption {
          type = package;
          description = "Package providing `monerod`.";
        };

        extraArgs = mkOption {
          type = listOf str;
          default = [ ];
          description = "Extra command-line arguments passed to monerod.";
        };

        settings = mkOption {
          description = "monerod key-value configuration settings.";
          type = submodule {
            options = {
              # DAEMON
              log-file = mkOption {
                type = nullOr str;
                default = "/dev/stdout"; # DEVIATION: route logs to journald (monerod's default is <data-dir>/bitmonero.log)
                description = "Specify log file";
              };

              max-log-file-size = mkOption {
                type = nullOr ints.unsigned;
                default = null;
                defaultText = literalExpression "104850000";
                description = "Specify maximum log file size [B]";
              };

              max-log-files = mkOption {
                type = nullOr ints.unsigned;
                default = null;
                defaultText = literalExpression "50";
                description = "Specify maximum number of rotated log files to be saved (no limit by setting to 0)";
              };

              log-level = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''""'';
                description = ''
                  A preset 0-4 (0 = warnings, 1 = info, 2 = debug, 3-4 = trace),
                  a "category:level" list like "*:WARNING,net.p2p:DEBUG", or
                  both like "1,net.p2p:INFO"
                '';
              };

              max-concurrency = mkOption {
                type = nullOr ints.unsigned;
                default = null;
                defaultText = literalExpression "0";
                description = "Max number of threads to use for a parallel job";
              };

              proxy = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''""'';
                description = ''Network communication through proxy: <socks-ip:port> i.e. "127.0.0.1:9050"'';
              };

              proxy-allow-dns-leaks = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Allow DNS leaks outside of proxy";
              };

              public-node = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Allow other users to use the node as a remote (restricted RPC mode, view-only commands) and advertise it over P2P";
              };

              zmq-rpc-bind-ip = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''"127.0.0.1"'';
                description = "IP for ZMQ RPC server to listen on";
              };

              zmq-rpc-bind-port = mkOption {
                type = nullOr port;
                default = null;
                defaultText = literalExpression "18082";
                description = "Port for ZMQ RPC server to listen on";
              };

              zmq-pub = mkOption {
                type = listOf str;
                default = [ ];
                description = "Address for ZMQ pub - tcp://ip:port or ipc://path";
              };

              no-zmq = mkOption {
                type = nullOr bool;
                default = null;
                description = "Disable ZMQ RPC server";
              };

              # CORE
              testnet = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Run on testnet. The wallet must be launched with --testnet flag.";
              };

              stagenet = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Run on stagenet. The wallet must be launched with --stagenet flag.";
              };

              regtest = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Run in a regression testing mode.";
              };

              keep-fakechain = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Don't delete any existing database when in fakechain mode.";
              };

              fixed-difficulty = mkOption {
                type = nullOr ints.unsigned;
                default = null;
                defaultText = literalExpression "0";
                description = "Fixed difficulty used for testing.";
              };

              data-dir = mkOption {
                type = nullOr str;
                default = "."; # DEVIATION: use the systemd StateDirectory directly (monerod's default is ~/.bitmonero)
                description = "Specify data directory";
              };

              offline = mkOption {
                type = nullOr bool;
                default = null;
                description = "Do not listen for peers, nor connect to any";
              };

              disable-dns-checkpoints = mkOption {
                type = nullOr bool;
                default = null;
                description = "Do not retrieve checkpoints from DNS";
              };

              block-download-max-size = mkOption {
                type = nullOr ints.unsigned;
                default = null;
                defaultText = literalExpression "0";
                description = "Set maximum size of block download queue in bytes (0 for default)";
              };

              sync-pruned-blocks = mkOption {
                type = nullOr bool;
                default = null;
                description = "Allow syncing from nodes with only pruned blocks";
              };

              test-drop-download = mkOption {
                type = nullOr bool;
                default = null;
                description = "For net tests: in download, discard ALL blocks instead checking/saving them (very fast)";
              };

              test-drop-download-height = mkOption {
                type = nullOr ints.unsigned;
                default = null;
                defaultText = literalExpression "0";
                description = "Like test-drop-download but discards only after around certain height";
              };

              test-dbg-lock-sleep = mkOption {
                type = nullOr int;
                default = null;
                defaultText = literalExpression "0";
                description = "Sleep time in ms, defaults to 0 (off), used to debug before/after locking mutex. Values 100 to 1000 are good for tests.";
              };

              enforce-dns-checkpointing = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "checkpoints from DNS server will be enforced";
              };

              fast-block-sync = mkOption {
                type = nullOr ints.unsigned;
                default = null;
                defaultText = literalExpression "1";
                description = "Sync up most of the way by using embedded, known block hashes.";
              };

              prep-blocks-threads = mkOption {
                type = nullOr ints.unsigned;
                default = null;
                defaultText = literalExpression "4";
                description = "Max number of threads to use when preparing block hashes in groups.";
              };

              show-time-stats = mkOption {
                type = nullOr ints.unsigned;
                default = null;
                defaultText = literalExpression "0";
                description = "Show time-stats when processing blocks/txs and disk synchronization.";
              };

              block-sync-size = mkOption {
                type = nullOr ints.unsigned;
                default = null;
                defaultText = literalExpression "0";
                description = "How many blocks to sync at once during chain synchronization (0 = adaptive).";
              };

              check-updates = mkOption {
                type =
                  nullOr
                  <| enum [
                    "disabled"
                    "notify"
                    "download"
                    "update"
                  ];
                default = null;
                defaultText = literalExpression ''"notify"'';
                description = "Check for new versions of monero: [disabled|notify|download|update]";
              };

              fluffy-blocks = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "true";
                description = "Relay blocks as fluffy blocks (obsolete, now default)";
              };

              max-txpool-weight = mkOption {
                type = nullOr ints.unsigned;
                default = null;
                defaultText = literalExpression "648000000";
                description = "Set maximum txpool weight in bytes.";
              };

              block-notify = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''""'';
                description = "Run a program for each new block, '%s' will be replaced by the block hash";
              };

              prune-blockchain = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Prune blockchain";
              };

              reorg-notify = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''""'';
                description = "Run a program for each reorg, '%s' will be replaced by the split height, '%h' will be replaced by the new blockchain height, '%n' will be replaced by the number of new blocks in the new chain, and '%d' will be replaced by the number of blocks discarded from the old chain";
              };

              block-rate-notify = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''""'';
                description = "Run a program when the block rate undergoes large fluctuations. This might be a sign of large amounts of hash rate going on and off the Monero network, and thus be of potential interest in predicting attacks. %t will be replaced by the number of minutes for the observation window, %b by the number of blocks observed within that window, and %e by the number of blocks that was expected in that window. It is suggested that this notification is used to automatically increase the number of confirmations required before a payment is acted upon.";
              };

              keep-alt-blocks = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Keep alternative blocks on restart";
              };

              # DATABASE
              db-sync-mode = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''"fast:async:250000000bytes"'';
                description = "Specify sync option, using format [safe|fast|fastest]:[sync|async]:[<nblocks_per_sync>[blocks]|<nbytes_per_sync>[bytes]].";
              };

              db-salvage = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Try to salvage a blockchain database if it seems corrupted";
              };

              # MINER
              extra-messages-file = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''""'';
                description = "Specify file for extra messages to include into coinbase transactions";
              };

              start-mining = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''""'';
                description = "Specify wallet address to mining for";
              };

              mining-threads = mkOption {
                type = nullOr ints.unsigned;
                default = null;
                defaultText = literalExpression "0";
                description = "Specify mining threads count";
              };

              bg-mining-enable = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "true";
                description = "enable background mining";
              };

              bg-mining-ignore-battery = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "if true, assumes plugged in when unable to query system power status";
              };

              bg-mining-min-idle-interval = mkOption {
                type = nullOr ints.unsigned;
                default = null;
                defaultText = literalExpression "10";
                description = "Specify min lookback interval in seconds for determining idle state";
              };

              bg-mining-idle-threshold = mkOption {
                type = nullOr ints.unsigned;
                default = null;
                defaultText = literalExpression "90";
                description = "Specify minimum avg idle percentage over lookback interval";
              };

              bg-mining-miner-target = mkOption {
                type = nullOr ints.unsigned;
                default = null;
                defaultText = literalExpression "40";
                description = "Specify maximum percentage cpu use by miner(s)";
              };

              # RPC
              rpc-bind-ip = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''"127.0.0.1"'';
                description = "Specify IP to bind RPC server";
              };

              rpc-bind-ipv6-address = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''"::1"'';
                description = "Specify IPv6 address to bind RPC server";
              };

              rpc-restricted-bind-ip = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''"127.0.0.1"'';
                description = "Specify IP to bind restricted RPC server";
              };

              rpc-restricted-bind-ipv6-address = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''"::1"'';
                description = "Specify IPv6 address to bind restricted RPC server";
              };

              rpc-use-ipv6 = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Allow IPv6 for RPC";
              };

              rpc-ignore-ipv4 = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Ignore unsuccessful IPv4 bind for RPC";
              };

              rpc-bind-port = mkOption {
                type = nullOr port;
                default = null;
                defaultText = literalExpression "18081";
                description = "Port for RPC server";
              };

              rpc-restricted-bind-port = mkOption {
                type = nullOr port;
                default = null;
                description = "Port for restricted RPC server";
              };

              rpc-login = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''""'';
                description = "Specify username[:password] required for RPC server";
              };

              confirm-external-bind = mkOption {
                type = nullOr bool;
                default = null;
                description = "Confirm rpc-bind-ip value is NOT a loopback (local) IP";
              };

              rpc-access-control-origins = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''""'';
                description = "Specify a comma separated list of origins to allow cross origin resource sharing";
              };

              rpc-ssl = mkOption {
                type =
                  nullOr
                  <| enum [
                    "enabled"
                    "disabled"
                    "autodetect"
                  ];
                default = null;
                defaultText = literalExpression ''"autodetect"'';
                description = "Enable SSL on RPC connections: enabled|disabled|autodetect";
              };

              rpc-ssl-private-key = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''""'';
                description = "Path to a PEM format private key";
              };

              rpc-ssl-certificate = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''""'';
                description = "Path to a PEM format certificate";
              };

              rpc-ssl-ca-certificates = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''""'';
                description = "Path to file containing concatenated PEM format certificate(s) to replace system CA(s).";
              };

              rpc-ssl-allowed-fingerprints = mkOption {
                type = listOf str;
                default = [ ];
                description = "List of certificate fingerprints to allow";
              };

              rpc-ssl-allow-chained = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Allow user (via --rpc-ssl-certificates) chain certificates";
              };

              rpc-ssl-allow-any-cert = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Allow any peer certificate";
              };

              disable-rpc-ban = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Do not ban hosts on RPC errors";
              };

              restricted-rpc = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Restrict RPC to view only commands and do not return privacy sensitive data in RPC calls";
              };

              bootstrap-daemon-address = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''""'';
                description = "URL of a 'bootstrap' remote daemon that the connected wallets can use while this daemon is still not fully synced.\nUse 'auto' to enable automatic public nodes discovering and bootstrap daemon switching";
              };

              bootstrap-daemon-login = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''""'';
                description = "Specify username:password for the bootstrap daemon login";
              };

              bootstrap-daemon-proxy = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''""'';
                description = "<ip>:<port> socks proxy to use for bootstrap daemon connections";
              };

              rpc-payment-address = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''""'';
                description = "Restrict RPC to clients sending micropayment to this address";
              };

              rpc-payment-difficulty = mkOption {
                type = nullOr ints.unsigned;
                default = null;
                defaultText = literalExpression "1000";
                description = "Restrict RPC to clients sending micropayment at this difficulty";
              };

              rpc-payment-credits = mkOption {
                type = nullOr ints.unsigned;
                default = null;
                defaultText = literalExpression "100";
                description = "Restrict RPC to clients sending micropayment, yields that many credits per payment";
              };

              rpc-payment-allow-free-loopback = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Allow free access from the loopback address (ie, the local host)";
              };

              rpc-max-connections-per-public-ip = mkOption {
                type = nullOr ints.unsigned;
                default = null;
                defaultText = literalExpression "3";
                description = "Max RPC connections per public IP permitted";
              };

              rpc-max-connections-per-private-ip = mkOption {
                type = nullOr ints.unsigned;
                default = null;
                defaultText = literalExpression "25";
                description = "Max RPC connections per private and localhost IP permitted";
              };

              rpc-max-connections = mkOption {
                type = nullOr ints.unsigned;
                default = null;
                defaultText = literalExpression "100";
                description = "Max RPC connections permitted";
              };

              rpc-response-soft-limit = mkOption {
                type = nullOr ints.unsigned;
                default = null;
                defaultText = literalExpression "26214400";
                description = "Max response bytes that can be queued, enforced at next response attempt";
              };

              # P2P
              p2p-bind-ip = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''"0.0.0.0"'';
                description = "Interface for p2p network protocol (IPv4)";
              };

              p2p-bind-ipv6-address = mkOption {
                type = nullOr str;
                default = null;
                defaultText = literalExpression ''"::"'';
                description = "Interface for p2p network protocol (IPv6)";
              };

              p2p-bind-port = mkOption {
                type = nullOr port;
                default = null;
                defaultText = literalExpression "18080";
                description = "Port for p2p network protocol (IPv4)";
              };

              p2p-bind-port-ipv6 = mkOption {
                type = nullOr port;
                default = null;
                defaultText = literalExpression "18080";
                description = "Port for p2p network protocol (IPv6)";
              };

              p2p-external-port = mkOption {
                type = nullOr port;
                default = null;
                defaultText = literalExpression "0";
                description = "External port for p2p network protocol (if port forwarding used with NAT)";
              };

              allow-local-ip = mkOption {
                type = nullOr bool;
                default = null;
                description = "Allow local ip add to peer list, mostly in debug purposes";
              };

              add-peer = mkOption {
                type = listOf str;
                default = [ ];
                description = "Manually add peer to local peerlist";
              };

              add-priority-node = mkOption {
                type = listOf str;
                default = [ ];
                description = "Specify list of peers to connect to and attempt to keep the connection open";
              };

              add-exclusive-node = mkOption {
                type = listOf str;
                default = [ ];
                description = "Specify list of peers to connect to only. If this option is given the options add-priority-node and seed-node are ignored";
              };

              seed-node = mkOption {
                type = listOf str;
                default = [ ];
                description = "Connect to a node to retrieve peer addresses, and disconnect";
              };

              tx-proxy = mkOption {
                type = listOf str;
                default = [ ];
                description = ''Send local txes through proxy: <network-type>,<socks-ip:port>[,max_connections][,disable_noise] i.e. "tor,127.0.0.1:9050,100,disable_noise"'';
              };

              anonymous-inbound = mkOption {
                type = listOf str;
                default = [ ];
                description = ''<hidden-service-address>,<[bind-ip:]port>[,max_connections] i.e. "x.onion,127.0.0.1:18083,100"'';
              };

              ban-list = mkOption {
                type = nullOr path;
                default = null;
                description = "Specify ban list file, one IP address per line";
              };

              hide-my-port = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Do not announce yourself as peerlist candidate";
              };

              no-sync = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Don't synchronize the blockchain with other peers";
              };

              enable-dns-blocklist = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Apply realtime blocklist from DNS";
              };

              no-igd = mkOption {
                type = nullOr bool;
                default = null;
                description = "Disable UPnP port mapping";
              };

              igd = mkOption {
                type =
                  nullOr
                  <| enum [
                    "disabled"
                    "enabled"
                    "delayed"
                  ];
                default = null;
                defaultText = literalExpression ''"delayed"'';
                description = "UPnP port mapping (disabled, enabled, delayed)";
              };

              p2p-use-ipv6 = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Enable IPv6 for p2p";
              };

              p2p-ignore-ipv4 = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Ignore unsuccessful IPv4 bind for p2p";
              };

              out-peers = mkOption {
                type = nullOr <| addCheck int (value: value >= -1);
                default = null;
                defaultText = literalExpression "-1";
                description = "set max number of out peers";
              };

              in-peers = mkOption {
                type = nullOr <| addCheck int (value: value >= -1);
                default = null;
                defaultText = literalExpression "-1";
                description = "set max number of in peers";
              };

              tos-flag = mkOption {
                type = nullOr int;
                default = null;
                defaultText = literalExpression "-1";
                description = "set TOS flag";
              };

              limit-rate-up = mkOption {
                type = nullOr <| addCheck int (value: value >= -1);
                default = null;
                defaultText = literalExpression "8192";
                description = "set limit-rate-up [kB/s]";
              };

              limit-rate-down = mkOption {
                type = nullOr <| addCheck int (value: value >= -1);
                default = null;
                defaultText = literalExpression "32768";
                description = "set limit-rate-down [kB/s]";
              };

              limit-rate = mkOption {
                type = nullOr <| addCheck int (value: value >= -1);
                default = null;
                defaultText = literalExpression "-1";
                description = "set limit-rate [kB/s]";
              };

              pad-transactions = mkOption {
                type = nullOr bool;
                default = null;
                defaultText = literalExpression "false";
                description = "Pad relayed transactions to help defend against traffic volume analysis";
              };

              max-connections-per-ip = mkOption {
                type = nullOr ints.u32;
                default = null;
                defaultText = literalExpression "1";
                description = "Maximum number of p2p connections allowed from the same IP address";
              };
            };
          };
        };
      };

      config = {
        exec.allowMemory = true; # RandomX JIT is required even for block verification.
        exec.again = "always";

        limits.syscalls = singleton "@system-service";
        limits.fd = 65536;
        limits.storage = "10G"; # Enables the state directory for the blockchain (data-dir = "."); cap to the deployment's disk.

        network = {
          # monerod dials out to arbitrary public peers, so it may reach anywhere.
          reach = [
            "0.0.0.0/0"
            "::/0"
          ];

          bind =
            let
              portOf =
                address:
                address
                |> splitString ":"
                |> last
                |> toInt;

              configuredOrDefaultPort =
                name:
                if cfg.settings.${name} != null then
                  cfg.settings.${name}
                else
                  toInt (options.monerod.settings.type.getSubOptions [ ]).${name}.defaultText.text;

              # A TCP listener on the given family, bound only when its address is set.
              listener =
                family: ipName: portName:
                optional (cfg.settings.${ipName} != null) { ${family}.tcp = configuredOrDefaultPort portName; };

              # Restricted RPC shares one port across its per-family addresses; the
              # port has no default, so its presence gates the listener.
              restricted =
                family: ipName:
                optional (cfg.settings.rpc-restricted-bind-port != null && cfg.settings.${ipName} != null) {
                  ${family}.tcp = cfg.settings.rpc-restricted-bind-port;
                };
            in
            # monerod's outbound peer connections are TCP (connect-autobind, which
            # escapes SocketBindDeny), so the bind list restricts only listeners,
            # each bound once its bind address is set.
            listener "v4" "p2p-bind-ip" "p2p-bind-port"
            ++ listener "v6" "p2p-bind-ipv6-address" "p2p-bind-port-ipv6"
            ++ listener "v4" "rpc-bind-ip" "rpc-bind-port"
            ++ listener "v6" "rpc-bind-ipv6-address" "rpc-bind-port"
            ++ restricted "v4" "rpc-restricted-bind-ip"
            ++ restricted "v6" "rpc-restricted-bind-ipv6-address"
            ++ optional (cfg.settings.zmq-rpc-bind-ip != null) {
              ${familyOf cfg.settings.zmq-rpc-bind-ip}.tcp = configuredOrDefaultPort "zmq-rpc-bind-port";
            }
            ++ (
              cfg.settings.zmq-pub
              |> map (
                address:
                let
                  parts = match "([^:]+)://(.*)" address;
                  endpoint = elemAt parts 1;
                in
                getAttr (elemAt parts 0) {
                  tcp = {
                    ${familyOf endpoint}.tcp = portOf endpoint;
                  };
                  ipc = {
                    unix = endpoint;
                  };
                }
              )
            )
            ++ (
              cfg.settings.anonymous-inbound
              |> map (
                entry:
                let
                  endpoint = elemAt (splitString "," entry) 1;
                in
                {
                  ${familyOf endpoint}.tcp = portOf endpoint;
                }
              )
            );
        };

        configData."monerod.conf".text =
          cfg.settings
          |> filterAttrs (_: value: value != null)
          |> toKeyValue {
            listsAsDuplicateKeys = true;

            mkKeyValue = mkKeyValueDefault {
              mkValueString =
                value:
                if value == true then
                  "1"
                else if value == false then
                  "0"
                else if typeOf value == "path" then
                  "${value}"
                else
                  mkValueStringDefault { } value;
            } "=";
          };

        exec.argv = [
          (getExe' cfg.package "monerod")
          "--config-file=${config.configData."monerod.conf".path}"
          "--non-interactive"
        ]
        ++ cfg.extraArgs;

        ${if options ? systemd then "systemd" else null}.service = {
          description = "Monero node daemon";
          unitConfig.Documentation = "https://docs.getmonero.org/running-node/monerod-systemd/";

          after = singleton "network-online.target";
          wants = singleton "network-online.target";
          wantedBy = singleton "multi-user.target";

          restartTriggers = singleton config.configData."monerod.conf".source;
        };
      };
    };
}
