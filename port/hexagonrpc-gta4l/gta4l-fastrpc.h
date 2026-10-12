/* SPDX-License-Identifier: MIT
 * Samsung sm6115 4.19 adsprpc_shared.h buffer-only UAPI adapter.
 * Layouts follow kernel commit 381a5549ee66fa751f632ee0840f5631274209ee.
 * This package is specific to 64-bit downstream SM-T505 userspace.
 */
#ifndef GTA4L_FASTRPC_H
#define GTA4L_FASTRPC_H
#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <misc/fastrpc.h>

struct gta4l_rpc_arg { uint64_t ptr, length; };
struct gta4l_rpc_invoke { uint32_t handle, sc; uint64_t args; };
struct gta4l_rpc_init {
    uint32_t flags;
    uint64_t file;
    uint32_t filelen;
    int32_t filefd;
    uint64_t mem;
    uint32_t memlen;
    int32_t memfd;
};
struct gta4l_rpc_mmap {
    int32_t fd;
    uint32_t flags;
    uint64_t vaddrin, size, vaddrout;
};
_Static_assert(sizeof(void *) == 8, "SM-T505 ARM64 adapter");
_Static_assert(sizeof(struct gta4l_rpc_arg) == 16, "remote_arg layout");
_Static_assert(sizeof(struct gta4l_rpc_invoke) == 16, "invoke layout");
_Static_assert(sizeof(struct gta4l_rpc_init) == 40, "init layout");
_Static_assert(sizeof(struct gta4l_rpc_mmap) == 32, "mmap layout");

static inline int gta4l_rpc_attach_sensors(int fd)
{
    /* GETINFO selects domain 0 (ADSP) before INIT attaches sensorspd (2). */
    uint32_t domain = 0;
    struct gta4l_rpc_init init = { .flags = 3, .filefd = -1, .memfd = -1 };
    if (ioctl(fd, _IOWR('R', 8, uint32_t), &domain))
        return -1;
    return ioctl(fd, _IOWR('R', 6, struct gta4l_rpc_init), &init);
}

static inline int gta4l_rpc_invoke(int fd, const struct fastrpc_invoke *request,
                                  const struct fastrpc_invoke_args *args, size_t n)
{
    struct gta4l_rpc_arg *buffers = calloc(n ? n : 1, sizeof(*buffers));
    struct gta4l_rpc_invoke invoke = { request->handle, request->sc, 0 };
    int ret, saved_errno;
    if (!buffers) { errno = ENOMEM; return -1; }
    for (size_t i = 0; i < n; i++) {
        /* No DMA handles are passed by this sensor file server. */
        if (args[i].fd != -1 || args[i].attr != 0) {
            free(buffers); errno = ENOTSUP; return -1;
        }
        buffers[i].ptr = args[i].ptr;
        buffers[i].length = args[i].length;
    }
    invoke.args = (uint64_t)buffers;
    ret = ioctl(fd, _IOWR('R', 1, struct gta4l_rpc_invoke), &invoke);
    saved_errno = errno;
    free(buffers);
    errno = saved_errno;
    return ret;
}

static inline int gta4l_rpc_mmap(int fd, struct fastrpc_req_mmap *request)
{
    struct gta4l_rpc_mmap map = { request->fd, request->flags,
                                request->vaddrin, request->size, 0 };
    int ret = ioctl(fd, _IOWR('R', 14, struct gta4l_rpc_mmap), &map);
    if (!ret) request->vaddrout = map.vaddrout;
    return ret;
}
#endif
