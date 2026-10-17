# Userspace compatibility on the downstream kernel

The port retains Samsung's 4.19.300 kernel and vendor drivers. New desktop
packages also need APIs introduced after that kernel version. Each backport
keeps the device drivers and existing syscall semantics, and is tested on the
tablet separately from image assembly.

Kernel #10 (APK 4.19.300-r9) completes `waitid(P_PIDFD)` for the already present
`pidfd_open` API. GNOME's session manager otherwise reports child-watch errors
and delays login. The hardware test checks descriptor errors, child ownership,
nonblocking waits, exit status, observing without reaping, and final reaping.
Kernel #10 also remaps four vendor gesture keys from Linux mouse-button codes
to F13–F16. Libinput then identifies the Himax device as a touchscreen, allowing
Mutter's touch-dependent rotation policy to engage.

The kernel #11 candidate (APK 4.19.300-r10) adds `faccessat2`, following
[Linux v5.8's implementation](https://github.com/torvalds/linux/blob/v5.8/fs/open.c).
GLib uses a no-follow access check for local file existence. On this musl system,
the old syscall cannot represent that flag: a real file is present according to
POSIX but `Gio.File.query_exists()` returns false with an unsupported-flags error.
The new syscall supports no-follow, effective-ID and empty-path checks. The
backport preserves Samsung's `inode_permission2` and mount restrictions, keeps
the three-argument in-kernel helper, and registers syscall 439 for native ARM64
and its ARM32 compatibility table. The package's driver configuration is unchanged.

The candidate built locally in WSL Ubuntu. All 37 modules, DTBs and the ramdisk
match kernel #10 exactly. Its guarded OrangeFox
update writes only boot and verifies readback. Runtime tests pass for existing
and missing files, dangling symlinks, relative directory descriptors, empty
paths, invalid inputs, real versus effective UID permissions, the legacy access
API, and GLib checks as the tablet user. An ARM32 EABI executable also passes
the compatibility dispatch checks without a libc dependency. The previous
pidfd and Himax capability tests pass again. The active GNOME compositor maps
private Zink/Turnip and has Adreno open; the user confirms desktop, Settings,
Files, rotation, touch and keyboard. The verified boot-only update preserves
userdata and recovery. Evidence is under
`evidence/ui-qc/gnome/20261016T190657Z-file-access-kernel-fix/`.
The working #9 and #10 boot images remain separate rollback files.
