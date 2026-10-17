#!/usr/bin/env python3
"""Collect four visible touch targets without changing device calibration."""
import json
from pathlib import Path
import time
import dbus
import gi
gi.require_version('Gtk', '3.0')
gi.require_version('Gdk', '3.0')
from gi.repository import Gdk, GLib, Gtk

session_bus = dbus.SessionBus()
screen_saver = dbus.Interface(session_bus.get_object('org.freedesktop.ScreenSaver', '/ScreenSaver'),
                             'org.freedesktop.ScreenSaver')
inhibitor = screen_saver.Inhibit('Touch alignment check', 'Measuring touchscreen coordinates')

targets = [(0.12, 0.16), (0.88, 0.16), (0.12, 0.84), (0.5, 0.5)]
samples = []
last_press = 0.0
state = Path.home() / '.cache/gta4l-ui-qc'
state.mkdir(parents=True, exist_ok=True, mode=0o700)
output = state / 'touch-samples.json'
window = Gtk.Window(title='Touch alignment check')
window.fullscreen()
window.connect('destroy', Gtk.main_quit)
area = Gtk.EventBox()
area.add_events(Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.TOUCH_MASK)
window.add(area)
fixed = Gtk.Fixed()
area.add(fixed)
title = Gtk.Label()
dot = Gtk.Label(label='●')
title.set_name('touch-instructions')
dot.set_name('touch-target')
area.set_name('touch-surface')
fixed.put(title, 30, 200)
fixed.put(dot, 50, 50)
css = Gtk.CssProvider()
css.load_from_data(b'''#touch-surface { background-color: #121720; }
#touch-instructions { color: white; font-size: 24px; }
#touch-target { color: #1aa6ff; font-size: 76px; }''')
Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

def update_layout(widget, allocation=None):
    width, height = widget.get_allocated_width(), widget.get_allocated_height()
    text = 'Tap the blue dot (' + str(len(samples) + 1) + '/4)' if len(samples) < 4 else 'Touch samples saved'
    title.set_text(text)
    fixed.move(title, int(width * 0.12), int(height * 0.45))
    if len(samples) < 4:
        x, y = targets[len(samples)]
        dot_width = dot.get_preferred_width()[1]
        dot_height = dot.get_preferred_height()[1]
        fixed.move(dot, int(x * width - dot_width / 2), int(y * height - dot_height / 2))
    else:
        dot.hide()

def press(widget, event):
    global last_press
    if event.type not in (Gdk.EventType.BUTTON_PRESS, Gdk.EventType.TOUCH_BEGIN):
        return False
    now = time.monotonic()
    if now - last_press < 0.7 or len(samples) >= len(targets):
        return True
    last_press = now
    width, height = widget.get_allocated_width(), widget.get_allocated_height()
    samples.append({'target': targets[len(samples)], 'observed': [event.x / width, event.y / height],
                    'window': [width, height], 'event_type': int(event.type)})
    output.write_text(json.dumps({'samples': samples, 'complete': len(samples) == 4}, indent=2) + '\n')
    update_layout(widget)
    if len(samples) == 4:
        GLib.timeout_add_seconds(4, lambda: (window.destroy(), False)[1])
    return True

area.connect('size-allocate', update_layout)
area.connect('button-press-event', press)
area.connect('touch-event', press)
GLib.timeout_add_seconds(300, lambda: (window.destroy(), False)[1])
window.show_all()
Gtk.main()
screen_saver.UnInhibit(inhibitor)
