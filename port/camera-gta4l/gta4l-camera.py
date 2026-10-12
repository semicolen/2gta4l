#!/usr/bin/env python3
"""Native GTK camera preview and photo saving for the SM-T505 stock HAL."""
import argparse, json, os, queue, socket, threading, time
from datetime import datetime
from pathlib import Path
import gi
gi.require_version('Gtk','3.0')
from gi.repository import Gtk, GdkPixbuf, GLib

class Camera(Gtk.Window):
    def __init__(self):
        super().__init__(title='Camera')
        self.set_default_size(800,900)
        self.commands=queue.Queue(); self.closed=False
        self.current_camera=None; self.last_identity=None; self.last_frame=None
        self.preview_camera=None; self.status={}
        self.taking_photo=False; self.handled_photo_id=None; self.notice=None
        self.connect('destroy',self.close_camera)
        box=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=12)
        box.set_border_width(12); self.add(box)
        toolbar=Gtk.Box(spacing=12)
        self.camera_buttons=[]
        for label,command in [('Rear camera','rear'),('Front camera','front'),('Stop','stop')]:
            button=Gtk.Button(label=label)
            button.connect('clicked',lambda _button,c=command:self.select(c))
            self.camera_buttons.append(button)
            toolbar.pack_start(button,True,True,0)
        box.pack_start(toolbar,False,False,0)
        self.image=Gtk.Image()
        box.pack_start(self.image,True,True,0)
        self.label=Gtk.Label(label='Choose a camera to start preview')
        self.label.set_line_wrap(True); box.pack_start(self.label,False,False,0)
        self.save=Gtk.Button(label='Take photo')
        self.save.set_sensitive(False); self.save.connect('clicked',self.take_photo)
        box.pack_start(self.save,False,False,0)
        threading.Thread(target=self.worker,daemon=True).start()
        GLib.timeout_add(200,self.refresh)

    def select(self,name):
        self.current_camera=name if name!='stop' else None
        self.last_identity=None; self.last_frame=None; self.preview_camera=None
        self.save.set_sensitive(False); self.image.clear()
        self.label.set_text('Starting '+name+' camera…' if name!='stop' else 'Camera stopped')
        self.commands.put(name)

    def worker(self):
        try:
            with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as connection:
                connection.settimeout(20)
                connection.connect('/run/gta4l-camera/control.sock')
                pending=b''
                while not self.closed:
                    try: command=self.commands.get(timeout=0.75)
                    except queue.Empty: command='status'
                    connection.sendall(command.encode()+b'\n')
                    while b'\n' not in pending:
                        data=connection.recv(1024)
                        if not data: raise OSError('Camera service disconnected')
                        pending+=data
                    line,pending=pending.split(b'\n',1)
                    self.status=json.loads(line)
                    if (self.status.get('mode')=='photo' and
                        self.status.get('exit_status') is not None and
                        self.status.get('photo_id')!=self.handled_photo_id):
                        self.handled_photo_id=self.status['photo_id']
                        GLib.idle_add(self.finish_photo,dict(self.status))
        except (OSError,ValueError) as error:
            GLib.idle_add(self.label.set_text,'Camera unavailable: '+str(error))

    def rotation(self):
        try:
            state=json.loads((Path.home()/'.cache/gta4l-rotation/status.json').read_text())
            orientation=state.get('applied','normal')
        except (OSError,ValueError): orientation='normal'
        # Sensor orientation is 90 degrees rear, 270 degrees front relative
        # to the tablet's normal portrait orientation.
        angle=(90 if self.current_camera=='rear' else 270)+{
            'normal':0,'bottom-up':180,'left-up':270,'right-up':90}.get(orientation,0)
        return angle%360

    def refresh(self):
        if self.closed: return False
        if self.taking_photo: return True
        if not self.current_camera: return True
        if self.status.get('camera')!=self.current_camera: return True
        if self.status.get('exit_status') is not None:
            self.label.set_text('Camera stopped unexpectedly. Select a camera to retry.')
            self.save.set_sensitive(False); return True
        path=Path('/run/gta4l-camera/frames/frame.ppm')
        try:
            identity=(path.stat().st_ino,path.stat().st_mtime_ns,self.rotation())
            if identity==self.last_identity: return True
            frame=GdkPixbuf.Pixbuf.new_from_file(str(path))
            rotation={0:GdkPixbuf.PixbufRotation.NONE,90:GdkPixbuf.PixbufRotation.CLOCKWISE,
                      180:GdkPixbuf.PixbufRotation.UPSIDEDOWN,270:GdkPixbuf.PixbufRotation.COUNTERCLOCKWISE}[identity[2]]
            frame=frame.rotate_simple(rotation)
            if self.current_camera=='front': frame=frame.flip(True)
            self.last_identity=identity; self.last_frame=frame
            self.preview_camera=self.current_camera
            allocation=self.image.get_allocation()
            scale=min(max(1,allocation.width)/frame.get_width(),
                      max(1,allocation.height)/frame.get_height(),1.5)
            self.image.set_from_pixbuf(frame.scale_simple(max(1,int(frame.get_width()*scale)),
                max(1,int(frame.get_height()*scale)),GdkPixbuf.InterpType.BILINEAR))
            self.save.set_sensitive(True)
            self.label.set_text(self.notice[0] if self.notice and time.monotonic()<self.notice[1]
                                else self.current_camera.title()+' camera')
        except (OSError,GLib.Error): pass
        return True

    def take_photo(self,_button):
        if self.last_frame is None or self.preview_camera!=self.current_camera: return
        self.taking_photo=True
        self.photo_camera=self.current_camera; self.photo_angle=self.rotation()
        self.save.set_sensitive(False)
        for button in self.camera_buttons: button.set_sensitive(False)
        self.label.set_text('Taking full-resolution photo…')
        self.commands.put('photo')

    def finish_photo(self,state):
        if self.closed: return False
        message='Photo capture failed. Preview is restarting.'
        folder=Path.home()/'Pictures/Camera'
        try:
            if not state.get('photo_ready') or state.get('camera')!=self.photo_camera:
                raise OSError('Camera did not return a complete photo')
            frame=GdkPixbuf.Pixbuf.new_from_file('/run/gta4l-camera/frames/photo.ppm')
            expected={'rear':(3264,2448),'front':(2592,1944)}[self.photo_camera]
            if (frame.get_width(),frame.get_height())!=expected: raise OSError('Unexpected photo size')
            rotation={0:GdkPixbuf.PixbufRotation.NONE,90:GdkPixbuf.PixbufRotation.CLOCKWISE,
                      180:GdkPixbuf.PixbufRotation.UPSIDEDOWN,270:GdkPixbuf.PixbufRotation.COUNTERCLOCKWISE}[self.photo_angle]
            frame=frame.rotate_simple(rotation)
            if self.photo_camera=='front': frame=frame.flip(True)
            folder.mkdir(mode=0o700,parents=True,exist_ok=True)
            path=folder/(datetime.now().strftime('%Y-%m-%d_%H-%M-%S-%f')+'_'+self.photo_camera+'.png')
            frame.savev(str(path),'png',[],[]); path.chmod(0o600)
            message=f'Saved {frame.get_width()}×{frame.get_height()} photo to Pictures/Camera'
        except (OSError,GLib.Error) as error: message='Could not save photo: '+str(error)
        self.notice=(message,time.monotonic()+6)
        self.label.set_text(message)
        self.taking_photo=False; self.last_identity=None
        for button in self.camera_buttons: button.set_sensitive(True)
        self.commands.put('photo-done')
        return False

    def close_camera(self,_window):
        self.closed=True
        Gtk.main_quit()

arguments=argparse.ArgumentParser()
arguments.add_argument('--camera',choices=('rear','front'))
options=arguments.parse_args()
os.umask(0o077)
window=Camera(); window.show_all()
if options.camera: GLib.idle_add(window.select,options.camera)
Gtk.main()
