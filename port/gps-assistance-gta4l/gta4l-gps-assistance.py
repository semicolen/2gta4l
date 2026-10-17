#!/usr/bin/python3
# SPDX-License-Identifier: MIT
"""Load receiver-advertised orbit data on demand without enabling location."""
from pathlib import Path
import argparse,fcntl,hashlib,json,os,signal,tempfile,threading,time,urllib.parse,urllib.request
import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

NAME='org.freedesktop.ModemManager1'
LOCATION=NAME+'.Modem.Location'
MANAGER='/org/freedesktop/ModemManager1'
CACHE=Path('/var/cache/gta4l-gps-assistance')
LIMIT=2*1024*1024
MAX_AGE=6*60*60
STOP=threading.Event()

def log(message):
    print('gta4l-gps-assistance: '+message,flush=True)

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs):
        raise ValueError('Assistance redirects are disabled')

def allowed(url):
    parsed=urllib.parse.urlsplit(url)
    return (parsed.scheme=='https' and parsed.netloc in
        ('path1.xtracloud.net','path2.xtracloud.net','path3.xtracloud.net') and
        parsed.path=='/xtra3grcej.bin' and not parsed.query and not parsed.fragment)

def atomic(path,data):
    fd,name=tempfile.mkstemp(prefix='.assistance-',dir=CACHE)
    try:
        with os.fdopen(fd,'wb') as stream:
            stream.write(data);stream.flush();os.fsync(stream.fileno())
        os.replace(name,path)
    finally:
        if os.path.exists(name):os.unlink(name)

def cached():
    try:
        info=json.loads((CACHE/'state.json').read_text())
        if not 0<=time.time()-info['downloaded_at']<MAX_AGE:return None
        with (CACHE/'xtra3grcej.bin').open('rb') as stream:data=stream.read(LIMIT+1)
        if 1024<=len(data)<=LIMIT and hashlib.sha256(data).hexdigest()==info['sha256']:
            return data,info
    except (OSError,ValueError,KeyError,TypeError):pass
    return None

def assistance(path,require_active=True):
    bus=dbus.SystemBus(private=True)
    try:
        owner=str(bus.get_name_owner(NAME))
        obj=bus.get_object(NAME,path)
        properties=dbus.Interface(obj,'org.freedesktop.DBus.Properties')
        props=properties.GetAll(LOCATION,timeout=5)
        if not int(props['SupportedAssistanceData'])&1:return False
        if require_active and not int(props['Enabled'])&6:return False
        value=cached()
        if value:
            data,info=value;log('using cached orbit data')
        else:
            opener=urllib.request.build_opener(NoRedirect)
            data=None;info=None
            for entry in props['AssistanceDataServers']:
                if STOP.is_set():return False
                url=str(entry)
                if not allowed(url):continue
                try:
                    request=urllib.request.Request(url,headers={'User-Agent':'postmarketOS-gta4l-gps/1.0'})
                    with opener.open(request,timeout=12) as response:
                        if response.status!=200:continue
                        candidate=response.read(LIMIT+1)
                    if not 1024<=len(candidate)<=LIMIT or candidate.lstrip().startswith((b'<',b'{')):continue
                    data=candidate
                    info={'downloaded_at':int(time.time()),'sha256':hashlib.sha256(data).hexdigest(),
                        'bytes':len(data),'source':urllib.parse.urlsplit(url).hostname}
                    atomic(CACHE/'xtra3grcej.bin',data)
                    atomic(CACHE/'state.json',(json.dumps(info)+'\n').encode())
                    log('downloaded orbit data (%d bytes)'%len(data));break
                except (OSError,ValueError):log('assistance server unavailable; trying another')
            if data is None:return False
        if STOP.is_set() or str(bus.get_name_owner(NAME))!=owner:return False
        props=properties.GetAll(LOCATION,timeout=5)
        if require_active and not int(props['Enabled'])&6:return False
        started=time.monotonic()
        dbus.Interface(obj,LOCATION).InjectAssistanceData(dbus.ByteArray(data),timeout=90)
        info['injected_at']=int(time.time())
        atomic(CACHE/'state.json',(json.dumps(info)+'\n').encode())
        log('modem accepted orbit data in %.2f seconds'%(time.monotonic()-started))
        return True
    finally:bus.close()

class Watcher:
    def __init__(self):
        self.bus=dbus.SystemBus();self.loop=GLib.MainLoop()
        self.busy=False;self.queued=False;self.next_attempt={}
        self.bus.add_signal_receiver(self.properties_changed,signal_name='PropertiesChanged',
            dbus_interface='org.freedesktop.DBus.Properties',bus_name=NAME)
        self.bus.add_signal_receiver(lambda *args:self.queue(),signal_name='InterfacesAdded',
            dbus_interface='org.freedesktop.DBus.ObjectManager',bus_name=NAME)
        self.bus.add_signal_receiver(self.owner_changed,signal_name='NameOwnerChanged',
            dbus_interface='org.freedesktop.DBus',arg0=NAME)
        for number in (signal.SIGTERM,signal.SIGINT):
            GLib.unix_signal_add(GLib.PRIORITY_DEFAULT,number,self.quit)
        self.queue()

    def quit(self):
        STOP.set();self.loop.quit();return False

    def owner_changed(self,*args):
        self.next_attempt.clear();self.queue()

    def properties_changed(self,interface,changed,invalidated):
        if str(interface)==LOCATION and ('Enabled' in changed or 'SupportedAssistanceData' in changed):self.queue()

    def queue(self):
        if not self.queued and not STOP.is_set():
            self.queued=True;GLib.idle_add(self.scan)

    def scan(self):
        self.queued=False
        if self.busy or STOP.is_set():return False
        try:
            owner=str(self.bus.get_name_owner(NAME))
            objects=dbus.Interface(self.bus.get_object(NAME,MANAGER),
                'org.freedesktop.DBus.ObjectManager').GetManagedObjects(timeout=5)
            for path,interfaces in objects.items():
                props=interfaces.get(LOCATION,{})
                if int(props.get('Enabled',0))&6 and int(props.get('SupportedAssistanceData',0))&1:
                    key=(owner,str(path))
                    if time.monotonic()<self.next_attempt.get(key,0):continue
                    self.busy=True
                    threading.Thread(target=self.work,args=(key,),daemon=True).start();break
        except dbus.DBusException:pass
        return False

    def work(self,key):
        ok=False
        try:ok=assistance(key[1])
        except dbus.DBusException as error:log('modem assistance failed: '+error.get_dbus_name())
        except (OSError,ValueError):log('assistance unavailable; satellite reception continues')
        GLib.idle_add(self.finished,key,ok)

    def finished(self,key,ok):
        self.busy=False
        delay=MAX_AGE if ok else 60
        self.next_attempt[key]=time.monotonic()+delay
        GLib.timeout_add_seconds(delay,self.retry)
        self.queue();return False

    def retry(self):self.queue();return False

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--once',action='store_true',help='Inject assistance once for a root diagnostic')
    args=parser.parse_args()
    if os.geteuid()!=0:parser.error('Run through the system service or a root diagnostic')
    os.umask(0o077)
    CACHE.mkdir(mode=0o700,parents=True,exist_ok=True)
    if CACHE.is_symlink() or CACHE.stat().st_uid!=0:raise RuntimeError('Unsafe assistance cache')
    CACHE.chmod(0o700)
    lock=open('/run/gta4l-gps-assistance.lock','w')
    fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    DBusGMainLoop(set_as_default=True)
    if args.once:
        bus=dbus.SystemBus()
        objects=dbus.Interface(bus.get_object(NAME,MANAGER),'org.freedesktop.DBus.ObjectManager').GetManagedObjects()
        path=next(p for p,v in objects.items() if LOCATION in v)
        return 0 if assistance(path,require_active=False) else 1
    log('watching location requests; GPS remains controlled by clients')
    Watcher().loop.run();return 0

if __name__=='__main__':raise SystemExit(main())
