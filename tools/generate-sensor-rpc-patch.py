from pathlib import Path
import tarfile
import difflib

root = Path(__file__).resolve().parents[1]
archive = Path('/home/ark/sm-t505-port/downloads/hexagonrpc-da7a3742ab8d5273a281b70ee11f16fb2cb6a690.tar.gz')
patch = []
replacements = {
    'libhexagonrpc/hexagonrpc.c': (
        'ret = ioctl(fd, FASTRPC_IOCTL_INVOKE, (__u64) &invoke);',
        'ret = gta4l_rpc_invoke(fd, &invoke, args, count.n_inbufs + count.n_outbufs);'),
    'hexagonrpcd/apps_mem.c': (
        'ret = ioctl(ctx->fd, FASTRPC_IOCTL_MMAP, &mmap);',
        'ret = gta4l_rpc_mmap(ctx->fd, &mmap);'),
    'hexagonrpcd/rpcd.c': (
        'ret = ioctl(fd, FASTRPC_IOCTL_INIT_ATTACH_SNS, NULL);',
        'ret = gta4l_rpc_attach_sensors(fd);'),
}
with tarfile.open(archive) as tar:
    prefix = tar.getnames()[0]
    for name, (old, new) in replacements.items():
        original = tar.extractfile(prefix + '/' + name).read().decode()
        assert original.count(old) == 1
        changed = original.replace(old, new).replace('#include <misc/fastrpc.h>', '#include <misc/fastrpc.h>\n#include "gta4l-fastrpc.h"')
        patch.extend(difflib.unified_diff(original.splitlines(True), changed.splitlines(True), fromfile='a/' + name, tofile='b/' + name))
    name = 'tests/test_hexagonrpc.c'
    original = tar.extractfile(prefix + '/' + name).read().decode()
    changed = original.replace('#include <misc/fastrpc.h>', '#include <misc/fastrpc.h>\n#include "gta4l-fastrpc.h"')
    changed = changed.replace('struct fastrpc_invoke *invoke;', 'struct gta4l_rpc_invoke *invoke;')
    changed = changed.replace('struct fastrpc_invoke_args *args;', 'struct gta4l_rpc_arg *args;')
    changed = changed.replace('(ioctl_operation) FASTRPC_IOCTL_INVOKE', "(ioctl_operation) _IOWR('R', 1, struct gta4l_rpc_invoke)")
    changed = changed.replace('(struct fastrpc_invoke_args *) invoke->args', '(struct gta4l_rpc_arg *) invoke->args')
    changed = changed.replace('\t\t\tif (args[i].fd != -1 || args[i].attr != 0)\n\t\t\t\treturn -1;\n\n', '')
    patch.extend(difflib.unified_diff(original.splitlines(True), changed.splitlines(True), fromfile='a/' + name, tofile='b/' + name))
(root / 'port/hexagonrpc-gta4l/downstream-fastrpc.patch').write_text(''.join(patch), newline='\n')
print('Generated downstream sensor FastRPC patch')
