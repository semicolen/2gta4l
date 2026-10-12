#!/usr/bin/env python3
"""Compare two conversions of the same private camera buffer on the tablet."""
import json
from pathlib import Path
import gi
gi.require_version('Gtk','3.0')
from gi.repository import Gtk,GdkPixbuf

directory=Path.home()/'.cache/gta4l-camera'
try:
    orientation=json.loads((Path.home()/'.cache/gta4l-rotation/status.json').read_text()).get('applied','normal')
except (OSError,ValueError): orientation='normal'
display_angle={'normal':0,'bottom-up':180,'left-up':270,'right-up':90}.get(orientation,0)
window=Gtk.Window(title='Camera color comparison')
window.set_default_size(800,850)
window.connect('destroy',Gtk.main_quit)
box=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=12)
box.set_border_width(12);window.add(box)
box.pack_start(Gtk.Label(label='Compare the colors of recognizable objects in both versions.'),False,False,0)
notebook=Gtk.Notebook();box.pack_start(notebook,True,True,0)
for camera,sensor_angle in [('rear',90),('front',270)]:
    page=Gtk.Box(spacing=12)
    for suffix,label in [('', 'A · Original'),('-swapped','B · Swapped chroma')]:
        column=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=12)
        column.pack_start(Gtk.Label(label=label),False,False,0)
        frame=GdkPixbuf.Pixbuf.new_from_file(str(directory/(camera+suffix+'.ppm')))
        rotation={0:GdkPixbuf.PixbufRotation.NONE,90:GdkPixbuf.PixbufRotation.CLOCKWISE,
                  180:GdkPixbuf.PixbufRotation.UPSIDEDOWN,270:GdkPixbuf.PixbufRotation.COUNTERCLOCKWISE}[(sensor_angle+display_angle)%360]
        frame=frame.rotate_simple(rotation)
        if camera=='front':frame=frame.flip(True)
        scale=min(350/frame.get_width(),650/frame.get_height(),1)
        frame=frame.scale_simple(int(frame.get_width()*scale),int(frame.get_height()*scale),GdkPixbuf.InterpType.BILINEAR)
        column.pack_start(Gtk.Image.new_from_pixbuf(frame),True,True,0)
        page.pack_start(column,True,True,0)
    notebook.append_page(page,Gtk.Label(label=camera.title()+' camera'))
button=Gtk.Button(label='Close');button.connect('clicked',lambda _button:window.destroy())
box.pack_start(button,False,False,0);window.show_all();Gtk.main()
