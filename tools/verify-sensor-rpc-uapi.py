"""Generate ARM64 build-time ABI checks against the actual kernel header."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
kernel = Path('/home/pmos/sm-t505-port/kernel/drivers/char/adsprpc_shared.h')
reference = kernel.read_text()
start = reference.index('#define remote_arg64_t')
end = reference.index('struct fastrpc_ioctl_munmap_fd', start)
reference = reference[start:end]
checks = '''
_Static_assert(sizeof(struct gta4l_rpc_arg) == sizeof(union remote_arg), "args");
_Static_assert(sizeof(struct gta4l_rpc_invoke) == sizeof(struct fastrpc_ioctl_invoke), "invoke");
_Static_assert(sizeof(struct gta4l_rpc_init) == sizeof(struct fastrpc_ioctl_init), "init");
_Static_assert(sizeof(struct gta4l_rpc_mmap) == sizeof(struct fastrpc_ioctl_mmap_64), "map64");
#define SAME(a, b, x, y) _Static_assert(offsetof(struct a, x) == offsetof(struct b, y), "offset")
SAME(gta4l_rpc_invoke, fastrpc_ioctl_invoke, args, pra);
SAME(gta4l_rpc_init, fastrpc_ioctl_init, flags, flags);
SAME(gta4l_rpc_init, fastrpc_ioctl_init, file, file);
SAME(gta4l_rpc_init, fastrpc_ioctl_init, filelen, filelen);
SAME(gta4l_rpc_init, fastrpc_ioctl_init, filefd, filefd);
SAME(gta4l_rpc_init, fastrpc_ioctl_init, mem, mem);
SAME(gta4l_rpc_init, fastrpc_ioctl_init, memlen, memlen);
SAME(gta4l_rpc_init, fastrpc_ioctl_init, memfd, memfd);
SAME(gta4l_rpc_mmap, fastrpc_ioctl_mmap_64, fd, fd);
SAME(gta4l_rpc_mmap, fastrpc_ioctl_mmap_64, flags, flags);
SAME(gta4l_rpc_mmap, fastrpc_ioctl_mmap_64, vaddrin, vaddrin);
SAME(gta4l_rpc_mmap, fastrpc_ioctl_mmap_64, size, size);
SAME(gta4l_rpc_mmap, fastrpc_ioctl_mmap_64, vaddrout, vaddrout);
int main(void) { puts("GTA4L_FASTRPC_KERNEL_ABI_VERIFIED"); return 0; }
'''
package = root/'port/hexagonrpc-gta4l'
(package/'gta4l-reference-uapi.h').write_text('/* SPDX-License-Identifier: GPL-2.0\n * Extracted from Samsung sm6115 adsprpc_shared.h, commit\n * 381a5549ee66fa751f632ee0840f5631274209ee.\n * Copyright (c) 2012-2020, The Linux Foundation. All rights reserved.\n */\n' + reference, newline='\n')
(package/'kernel-abi-test.c').write_text('#include <stddef.h>\n#include <stdio.h>\n#include <sys/types.h>\n#include "gta4l-fastrpc.h"\n#include "gta4l-reference-uapi.h"\n' + checks, newline='\n')
print('Generated field-layout checks against the actual downstream kernel UAPI')
