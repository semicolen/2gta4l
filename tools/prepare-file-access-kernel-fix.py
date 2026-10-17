#!/usr/bin/env python3
"""Backport faccessat2 without changing the vendor permission path or old API."""
from pathlib import Path
import difflib
import re

workspace = Path(__file__).resolve().parents[1]
kernel = Path('/home/ark/sm-t505-port/kernel')
package = workspace / 'port/linux-samsung-gta4l'
changes = []

path = 'fs/open.c'
old = (kernel / path).read_text()
start = old.index('long do_faccessat(int dfd, const char __user *filename, int mode)')
end = old.index('\nSYSCALL_DEFINE3(faccessat,', start)
function = old[start:end]
credential_start = function.index('\toverride_cred = prepare_creds();')
credential_end = function.index('\nretry:')
credentials = function[credential_start:credential_end]
credentials = credentials.replace('\t\treturn -ENOMEM;', '\t\treturn NULL;')
credentials += '\n\tput_cred(override_cred);\n\treturn old_cred;\n}\n\n'
helper = ('static const struct cred *access_override_creds(void)\n{\n'
          '\tconst struct cred *old_cred;\n\tstruct cred *override_cred;\n\n' + credentials)
function = function[:credential_start] + '''\tif (flags & ~(AT_EACCESS | AT_SYMLINK_NOFOLLOW | AT_EMPTY_PATH))
\t\treturn -EINVAL;
\tif (flags & AT_SYMLINK_NOFOLLOW)
\t\tlookup_flags &= ~LOOKUP_FOLLOW;
\tif (flags & AT_EMPTY_PATH)
\t\tlookup_flags |= LOOKUP_EMPTY;

\tif (!(flags & AT_EACCESS)) {
\t\told_cred = access_override_creds();
\t\tif (!old_cred)
\t\t\treturn -ENOMEM;
\t}
''' + function[credential_end:]
function = function.replace('long do_faccessat(int dfd, const char __user *filename, int mode)',
                            'static long do_faccessat_flags(int dfd, const char __user *filename,\n\t\t\t      int mode, int flags)')
function = function.replace('\tconst struct cred *old_cred;\n\tstruct cred *override_cred;',
                            '\tconst struct cred *old_cred = NULL;')
function = function.replace('\trevert_creds(old_cred);\n\tput_cred(override_cred);',
                            '\tif (old_cred)\n\t\trevert_creds(old_cred);')
function += '''
/* Keep the existing three-argument helper for downstream in-kernel callers. */
long do_faccessat(int dfd, const char __user *filename, int mode)
{
\treturn do_faccessat_flags(dfd, filename, mode, 0);
}

SYSCALL_DEFINE4(faccessat2, int, dfd, const char __user *, filename, int, mode,
\t\tint, flags)
{
\treturn do_faccessat_flags(dfd, filename, mode, flags);
}
'''
new = old[:start] + helper + function + old[end:]
assert new.count('inode_permission2(mnt, inode, mode | MAY_ACCESS)') == 1
changes.append((path, old, new))

path = 'include/uapi/linux/fcntl.h'
old = (kernel / path).read_text()
needle = '#define AT_SYMLINK_NOFOLLOW\t0x100   /* Do not follow symbolic links.  */'
assert old.count(needle) == 1 and '#define AT_EACCESS' not in old
new = old.replace(needle, needle + '\n#define AT_EACCESS\t\t0x200\t/* Test access permitted for effective IDs.  */')
changes.append((path, old, new))

path = 'include/linux/syscalls.h'
old = (kernel / path).read_text()
needle = 'asmlinkage long sys_faccessat(int dfd, const char __user *filename, int mode);'
assert old.count(needle) == 1
new = old.replace(needle, needle + '\nasmlinkage long sys_faccessat2(int dfd, const char __user *filename,\n\t\t\t      int mode, int flags);')
changes.append((path, old, new))

for path in ('include/uapi/asm-generic/unistd.h', 'arch/arm64/include/asm/unistd32.h'):
    old = (kernel / path).read_text()
    needle = '__SYSCALL(__NR_pidfd_open, sys_pidfd_open)'
    assert old.count(needle) == 1 and '__NR_faccessat2' not in old
    new = old.replace(needle, needle + '\n#define __NR_faccessat2 439\n__SYSCALL(__NR_faccessat2, sys_faccessat2)')
    if path.startswith('include/'):
        assert '#define __NR_syscalls 435' in new
        new = new.replace('#define __NR_syscalls 435', '#define __NR_syscalls 440')
    changes.append((path, old, new))

path = 'arch/arm64/include/asm/unistd.h'
old = (kernel / path).read_text()
new, count = re.subn(r'(__NR_compat_syscalls\s+)435\b', r'\g<1>440', old)
assert count == 1
changes.append((path, old, new))

patch = ('Backport Linux v5.8 faccessat2 flags and ARM64 syscall 439.\n'
         'Source: https://github.com/torvalds/linux/tree/v5.8 (fs/open.c and syscall tables).\n'
         'Retain Samsung inode_permission2, mount checks and the old do_faccessat API.\n'
         'GLib needs AT_SYMLINK_NOFOLLOW; preserve real/effective credential semantics.\n\n')
for path, old, new in changes:
    assert old != new, path
    patch += ''.join(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
                                        fromfile='a/' + path, tofile='b/' + path))
(package / 'faccessat2.patch').write_text(patch, newline='\n')
recipe = package / 'APKBUILD'
text = recipe.read_text()
assert re.search(r'^pkgrel=(9|10)$', text, re.M)
text = re.sub(r'^pkgrel=9$', 'pkgrel=10', text, flags=re.M)
if '\tfaccessat2.patch\n' not in text:
    text = text.replace('\thimax-gesture-keycodes.patch\n', '\thimax-gesture-keycodes.patch\n\tfaccessat2.patch\n')
recipe.write_text(text, newline='\n')
print('KERNEL11_FACCESSAT2_SOURCE_PREPARED')
