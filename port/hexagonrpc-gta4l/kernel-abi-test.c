#include <stddef.h>
#include <stdio.h>
#include <sys/types.h>
#include "gta4l-fastrpc.h"
#include "gta4l-reference-uapi.h"

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
