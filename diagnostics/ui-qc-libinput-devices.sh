#!/bin/sh
set -eu
python3 - <<'PY'
import ctypes as c, os
li=c.CDLL('libinput.so.10');udev=c.CDLL('libudev.so.1')
def fn(lib,name,ret,args):
    f=getattr(lib,name);f.restype=ret;f.argtypes=args;return f
ptr=c.c_void_p; integer=c.c_int
openfn=c.CFUNCTYPE(integer,c.c_char_p,integer,ptr)
closefn=c.CFUNCTYPE(None,integer,ptr)
@openfn
def open_device(path,flags,unused):
    try:return os.open(os.fsdecode(path),flags)
    except OSError as error:return -error.errno
@closefn
def close_device(fd,unused):os.close(fd)
class Interface(c.Structure):_fields_=[('open_restricted',openfn),('close_restricted',closefn)]
interface=Interface(open_device,close_device)
u=fn(udev,'udev_new',ptr,[])()
context=fn(li,'libinput_udev_create_context',ptr,[c.POINTER(Interface),ptr,ptr])(c.byref(interface),None,u)
assert context
try:
    assert fn(li,'libinput_udev_assign_seat',integer,[ptr,c.c_char_p])(context,b'seat0')==0
    fn(li,'libinput_dispatch',integer,[ptr])(context)
    get=fn(li,'libinput_get_event',ptr,[ptr]);kind=fn(li,'libinput_event_get_type',integer,[ptr])
    device=fn(li,'libinput_event_get_device',ptr,[ptr]);name=fn(li,'libinput_device_get_name',c.c_char_p,[ptr])
    sysname=fn(li,'libinput_device_get_sysname',c.c_char_p,[ptr])
    capability=fn(li,'libinput_device_has_capability',integer,[ptr,integer])
    switch=fn(li,'libinput_device_switch_has_switch',integer,[ptr,integer])
    destroy=fn(li,'libinput_event_destroy',None,[ptr])
    labels=('keyboard','pointer','touch','tablet-tool','tablet-pad','gesture','switch')
    while True:
        event=get(context)
        if not event:break
        try:
            if kind(event)==1:
                d=device(event)
                caps=[label for i,label in enumerate(labels) if capability(d,i)]
                print('LIBINPUT_DEVICE',sysname(d).decode(),repr(name(d).decode()),caps,
                      'tablet-switch',switch(d,2) if 'switch' in caps else False,flush=True)
        finally:destroy(event)
finally:
    fn(li,'libinput_unref',ptr,[ptr])(context)
    fn(udev,'udev_unref',ptr,[ptr])(u)
print('LIBINPUT_DEVICE_CAPABILITIES_COMPLETE',flush=True)
PY
