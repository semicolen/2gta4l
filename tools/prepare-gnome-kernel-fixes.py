#!/usr/bin/env python3
"""Prepare focused downstream fixes for GNOME input and child waiting."""
from pathlib import Path
import difflib,re
workspace=Path(__file__).resolve().parents[1]
kernel=Path('/home/ark/sm-t505-port/kernel')
package=workspace/'port/linux-samsung-gta4l'
def patch(name,changes,description):
    output=description+'\n\n'
    for path,new in changes:
        old=(kernel/path).read_text()
        assert old!=new,path
        output+=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),
                      fromfile='a/'+path,tofile='b/'+path))
    (package/name).write_text(output,newline='\n')
path='drivers/input/touchscreen/hxchipset/himax_common.h'
old=(kernel/path).read_text();new=old
for name,number,key in (('HX_KEY_DF_UP',272,'KEY_F13'),('HX_KEY_DF_DOWN',273,'KEY_F14'),
                        ('HX_KEY_DF_LEFT',274,'KEY_F15'),('HX_KEY_DF_RIGHT',275,'KEY_F16')):
    new,count=re.subn(r'^(#define\s+'+name+r'\s+)'+str(number)+r'$',lambda m:m[1]+key,new,flags=re.M)
    assert count==1,name
patch('himax-gesture-keycodes.patch',[(path,new)],
      'Map vendor double-finger gestures away from Linux mouse-button key codes.\n'
      'The four gestures retain distinct function-key events; touch and wake remain intact.')
exit_path='kernel/exit.c';old=(kernel/exit_path).read_text()
marker='static long kernel_waitid(int which, pid_t upid, struct waitid_info *infop,'
assert old.count(marker)==1
helper='''/* pidfd_open is backported in this tree; complete its waitid interface. */
static struct pid *wait_pidfd_get_pid(unsigned int fd)
{
\tstruct fd f = fdget(fd);
\tstruct pid *pid;

\tif (!f.file)
\t\treturn ERR_PTR(-EBADF);
\tif (f.file->f_op != &pidfd_fops)
\t\tpid = ERR_PTR(-EBADF);
\telse
\t\tpid = get_pid(f.file->private_data);
\tfdput(f);
\treturn pid;
}

'''
new=old.replace(marker,helper+marker)
start=new.index(marker);end=new.index('\nSYSCALL_DEFINE5(waitid,',start)
function=new[start:end]
needle='\tdefault:\n\t\treturn -EINVAL;\n\t}\n'
assert function.count(needle)==1
function=function.replace(needle,'''\tcase P_PIDFD:
\t\ttype = PIDTYPE_PID;
\t\tif (upid < 0)
\t\t\treturn -EINVAL;
\t\tpid = wait_pidfd_get_pid(upid);
\t\tif (IS_ERR(pid))
\t\t\treturn PTR_ERR(pid);
\t\tbreak;
'''+needle)
assert function.count('\tif (type < PIDTYPE_MAX)')==1
function=function.replace('\tif (type < PIDTYPE_MAX)','\tif (type < PIDTYPE_MAX && which != P_PIDFD)')
new=new[:start]+function+new[end:]
header_path='include/uapi/linux/wait.h';header=(kernel/header_path).read_text()
assert '#define P_PIDFD' not in header
header=header.replace('#define P_PGID\t\t2','#define P_PGID\t\t2\n#define P_PIDFD\t\t3')
patch('pidfd-waitid.patch',[(exit_path,new),(header_path,header)],
      'Complete waitid(P_PIDFD) for the already backported pidfd_open API.\n'
      'Based on Linux v5.4 kernel/exit.c: retain the pid reference, validate the fd\n'
      'and reuse the existing child-wait rules and ownership checks.')
recipe=package/'APKBUILD';text=recipe.read_text()
assert re.search(r'^pkgrel=(8|9)$',text,re.M)
text=re.sub(r'^pkgrel=8$', 'pkgrel=9',text,flags=re.M)
for name in ('himax-gesture-keycodes.patch','pidfd-waitid.patch'):
    if '\t'+name+'\n' not in text:
        text=text.replace('\trestore-bt-module-build.patch\n','\trestore-bt-module-build.patch\n\t'+name+'\n')
recipe.write_text(text,newline='\n')
print('KERNEL10_HIMAX_AND_PIDFD_SOURCE_FIXES_PREPARED')
