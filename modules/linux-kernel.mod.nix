{
  nixosModules.linux-kernel =
    {
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.modules) mkDefault;
    in
    {
      boot.kernelPackages = mkDefault pkgs.linuxPackages_latest;

      # Credits:
      # - https://github.com/NotAShelf/nyx/blob/main/modules/core/common/system/security/kernel.nix
      # - "hsslister" user - raf (NotAShelf) - "I actually forgot the dudes GitHub"
      boot.kernel.sysctl = {
        # The Magic SysRq key is a key combo that allows users connected to the
        # system console of a Linux kernel to perform some low-level commands.
        # Disable it, since we don't need it, and is a potential security concern.
        "kernel.sysrq" = 0;

        # Hide kptrs even for processes with CAP_SYSLOG.
        # Also prevents printing kernel pointers.
        "kernel.kptr_restrict" = 2;

        # Disable bpf() JIT (to eliminate spray attacks).
        "net.core.bpf_jit_enable" = false;

        # Disable ftrace debugging.
        "kernel.ftrace_enabled" = false;

        # Avoid kernel memory address exposures via dmesg (this value can also be set by CONFIG_SECURITY_DMESG_RESTRICT).
        "kernel.dmesg_restrict" = 1;

        # Prevent unintentional fifo writes.
        "fs.protected_fifos" = 2;

        # Prevent unintended writes to already-created files.
        "fs.protected_regular" = 2;

        # Disable SUID binary dump.
        "fs.suid_dumpable" = 0;

        # Disallow profiling at all levels without CAP_SYS_ADMIN.
        "kernel.perf_event_paranoid" = 3;

        # Require CAP_BPF to use bpf.
        "kernel.unprvileged_bpf_disabled" = 1;
      };

      # https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html
      boot.kernelParams = [
        # Make stack-based attacks on the kernel harder.
        "randomize_kstack_offset=on"

        # Controls the behavior of vsyscalls. This has been defaulted to none back in 2016 - break really old binaries for security.
        "vsyscall=none"

        # Reduce most of the exposure of a heap attack to a single cache.
        "slab_nomerge"

        # Only allow signed modules.
        "module.sig_enforce=1"

        # Blocks access to all kernel memory, even preventing administrators from being able to inspect and probe the kernel.
        "lockdown=confidentiality"

        # Enable buddy allocator free poisoning.
        "page_poison=1"

        # Performance improvement for direct-mapped memory-side-cache utilization, reduces the predictability of page allocations.
        "page_alloc.shuffle=1"

        # Disable sysrq keys. sysrq is seful for debugging, but also insecure.
        "sysrq_always_enabled=0"

        # Ignore access time (atime) updates on files, except when they coincide with updates to the ctime or mtime.
        "rootflags=noatime"

        # Linux security modules.
        "lsm=landlock,lockdown,yama,integrity,apparmor,bpf,tomoyo,selinux"

        # Prevent the kernel from blanking plymouth out of the fb.
        "fbcon=nodefer"
      ];

      boot.blacklistedKernelModules = [
        # Obscure network protocols.
        "af_802154" # IEEE 802.15.4
        "appletalk" # Appletalk
        "atm" # ATM
        "ax25" # Amatuer X.25
        "can" # Controller Area Network
        "dccp" # Datagram Congestion Control Protocol
        "decnet" # DECnet
        "econet" # Econet
        "ipx" # Internetwork Packet Exchange
        "n-hdlc" # High-level Data Link Control
        "netrom" # NetRom
        "p8022" # IEEE 802.3
        "p8023" # Novell raw IEEE 802.3
        "psnap" # SubnetworkAccess Protocol
        "rds" # Reliable Datagram Sockets
        "rose" # ROSE
        "sctp" # Stream Control Transmission Protocol
        "tipc" # Transparent Inter-Process Communication
        "x25" # X.25

        # Old or rare or insufficiently audited filesystems.
        "adfs" # Active Directory Federation Services
        "affs" # Amiga Fast File System
        "befs" # "Be File System"
        "bfs" # BFS, used by SCO UnixWare OS for the /stand slice
        "cifs" # Common Internet File System
        "cramfs" # compressed ROM/RAM file system
        "efs" # Extent File System
        "erofs" # Enhanced Read-Only File System
        "exofs" # EXtended Object File System
        "f2fs" # Flash-Friendly File System
        "freevxfs" # Veritas filesystem driver
        "gfs2" # Global File System 2
        "hfs" # Hierarchical File System (Macintosh)
        "hfsplus" # Same as above, but with extended attributes.
        "hpfs" # High Performance File System (used by OS/2)
        "jffs2" # Journalling Flash File System (v2)
        "jfs" # Journaled File System - only useful for VMWare sessions
        "ksmbd" # SMB3 Kernel Server
        "minix" # minix fs - used by the minix OS
        "nfs" # Network File System
        "nfsv3" # Network File System (v3)
        "nfsv4" # Network File System (v4)
        "nilfs2" # New Implementation of a Log-structured File System
        "omfs" # Optimized MPEG Filesystem
        "qnx4" # Extent-based file system used by the QNX4 OS.
        "qnx6" # Extent-based file system used by the QNX6 OS.
        "squashfs" # compressed read-only file system (used by live CDs)
        "sysv" # implements all of Xenix FS, SystemV/386 FS and Coherent FS.
        "udf" # https://docs.kernel.org/5.15/filesystems/udf.html
        "vivid" # Virtual Video Test Driver (unnecessary)

        # Disable Thunderbolt and FireWire to prevent DMA attacks
        "firewire-core"
        "thunderbolt"
      ];
    };

  nixosModules.linux-kernel-desktop =
    { pkgs, ... }:
    {
      boot.kernelPackages = pkgs.linuxKernel.packages.linux_zen;
    };
}
