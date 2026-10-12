#!/usr/bin/env python3
"""Show captured test frames in the existing tablet desktop session."""
from pathlib import Path
import json
import gi
gi.require_version('Gtk','3.0')
from gi.repository import Gtk, GdkPixbuf

directory=Path.home()/'.cache/gta4l-camera'
window=Gtk.Window(title='Galaxy Tab A7 camera test')
window.set_default_size(760,850)
window.connect('destroy',Gtk.main_quit)
box=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=12)
box.set_border_width(16)
window.add(box)
label=Gtk.Label(label='Captured camera test frames')
box.pack_start(label,False,False,0)
notebook=Gtk.Notebook()
box.pack_start(notebook,True,True,0)
try:
    orientation=json.loads((Path.home()/'.cache/gta4l-rotation/status.json').read_text()).get('applied','normal')
except (OSError,ValueError): orientation='normal'
display_angle={'normal':0,'bottom-up':180,'left-up':270,'right-up':90}.get(orientation,0)
for name,sensor,sensor_angle in [('Rear','HI846',90),('Front','GC5035',270)]:
    page=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=8)
    path=directory/(name.lower()+'.ppm')
    original=GdkPixbuf.Pixbuf.new_from_file(str(path))
    dimensions=f'{original.get_width()}×{original.get_height()}'
    rotation={0:GdkPixbuf.PixbufRotation.NONE,90:GdkPixbuf.PixbufRotation.CLOCKWISE,
              180:GdkPixbuf.PixbufRotation.UPSIDEDOWN,270:GdkPixbuf.PixbufRotation.COUNTERCLOCKWISE}[(sensor_angle+display_angle)%360]
    pixbuf=original.rotate_simple(rotation)
    if name=='Front': pixbuf=pixbuf.flip(True)
    scale=min(720/pixbuf.get_width(),700/pixbuf.get_height(),1)
    pixbuf=pixbuf.scale_simple(max(1,int(pixbuf.get_width()*scale)),
        max(1,int(pixbuf.get_height()*scale)),GdkPixbuf.InterpType.BILINEAR)
    image=Gtk.Image.new_from_pixbuf(pixbuf)
    page.pack_start(image,True,True,0)
    page.pack_start(Gtk.Label(label=name+' camera · '+sensor+' · '+dimensions),False,False,0)
    notebook.append_page(page,Gtk.Label(label=name+' camera'))
box.pack_start(Gtk.Label(label='These are still test images. Switch tabs to check both cameras.'),False,False,0)
button=Gtk.Button(label='Close')
button.connect('clicked',lambda _button:window.destroy())
box.pack_start(button,False,False,0)
window.show_all()
Gtk.main()
