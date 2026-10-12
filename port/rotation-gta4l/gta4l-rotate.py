#!/usr/bin/env python3
"""Rotate Xorg and Himax touch together using SensorProxy in the Xfce session."""
import argparse
import fcntl
import json
import logging
from logging.handlers import RotatingFileHandler
import os
from pathlib import Path
import re
import subprocess
import sys

# The panel's working portrait mode is inverted; touch is already calibrated
# for that mode. These are transforms relative to that verified baseline.
MODES = {
    'normal': ('inverted', (1, 0, 0, 0, 1, 0, 0, 0, 1)),
    'bottom-up': ('normal', (-1, 0, 1, 0, -1, 1, 0, 0, 1)),
    'left-up': ('right', (0, -1, 1, 1, 0, 0, 0, 0, 1)),
    'right-up': ('left', (0, 1, 0, -1, 0, 1, 0, 0, 1)),
}
CACHE = Path.home() / '.cache/gta4l-rotation'
CONFIG = Path.home() / '.config/gta4l-rotation'
STATE = CACHE / 'status.json'
PREFERENCE = CONFIG / 'preference.json'
NAME = 'net.hadess.SensorProxy'
OBJECT = '/net/hadess/SensorProxy'


def read_json(path):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return {}


def write_json(path, value):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temp = path.with_suffix('.tmp')
    temp.write_text(json.dumps(value) + '\n')
    temp.chmod(0o600)
    temp.replace(path)


def command(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True,
                          timeout=5).stdout


class Rotation:
    def __init__(self):
        import dbus
        import dbus.service
        from dbus.mainloop.glib import DBusGMainLoop
        from gi.repository import GLib
        self.dbus, self.glib = dbus, GLib
        DBusGMainLoop(set_as_default=True)
        self.bus = dbus.SystemBus()
        self.session_bus = dbus.SessionBus()
        self.session_name = dbus.service.BusName('org.postmarketos.Gta4l.Rotation', self.session_bus)
        class Control(dbus.service.Object):
            @dbus.service.method('org.freedesktop.DBus.Peer')
            def Ping(self):
                pass
        self.control = Control(self.session_name, '/org/postmarketos/Gta4l/Rotation')
        self.proxy = None
        self.claimed = False
        self.orientation = 'undefined'
        self.applied = None
        self.pending = None
        self.screen_on = True
        self.tick_count = 0
        self.bus.add_signal_receiver(self.changed, signal_name='PropertiesChanged',
            dbus_interface='org.freedesktop.DBus.Properties', path=OBJECT,
            bus_name=NAME)
        self.bus.add_signal_receiver(self.owner_changed, signal_name='NameOwnerChanged',
            dbus_interface='org.freedesktop.DBus', arg0=NAME)

    def owner_changed(self, name, old, new):
        self.proxy, self.claimed = None, False
        self.orientation = 'undefined'

    def changed(self, interface, changed, invalidated):
        if interface == NAME and 'AccelerometerOrientation' in changed:
            self.orientation = str(changed['AccelerometerOrientation'])
            if self.pending:
                self.glib.source_remove(self.pending)
            self.pending = self.glib.timeout_add(500, self.apply_pending)

    def apply_pending(self):
        self.pending = None
        self.update()
        return False

    def touch_ids(self):
        listing = command('xinput', '--list', '--short')
        return re.findall(r'himax-touchscreen\s+id=(\d+)\s+\[slave\s+pointer', listing)

    def apply(self, orientation):
        rotation, matrix = MODES[orientation]
        ids = self.touch_ids()
        if not ids:
            raise RuntimeError('Himax pointer not found; rotation postponed')
        previous = self.applied or 'normal'
        try:
            command('xrandr', '--output', 'DSI-1', '--rotate', rotation)
            for ident in ids:
                command('xinput', 'set-prop', ident, 'Coordinate Transformation Matrix',
                        *(str(x) for x in matrix))
        except Exception:
            # Restore both sides if an X command fails halfway through.
            old_rotation, old_matrix = MODES[previous]
            try:
                command('xrandr', '--output', 'DSI-1', '--rotate', old_rotation)
                for ident in ids:
                    command('xinput', 'set-prop', ident, 'Coordinate Transformation Matrix',
                            *(str(x) for x in old_matrix))
            except Exception:
                logging.exception('Could not restore the previous orientation')
            raise
        self.applied = orientation
        logging.info('Applied %s: DSI-1 %s, Himax %s', orientation, rotation, ids)

    def update(self):
        preference = read_json(PREFERENCE)
        locked = bool(preference.get('locked', False))
        wanted = preference.get('orientation', 'normal') if locked else self.orientation
        if self.screen_on and wanted in MODES and wanted != self.applied:
            try:
                self.apply(wanted)
            except Exception as error:
                logging.warning('Rotation deferred: %s', error)
        write_json(STATE, dict(pid=os.getpid(), locked=locked,
                   sensor=self.orientation, applied=self.applied, screen_on=self.screen_on))

    def tick(self):
        self.tick_count += 1
        try:
            if self.tick_count % 5 == 1:
                self.screen_on = 'Monitor is Off' not in command('xset', 'q')
            if self.proxy is None:
                self.proxy = self.dbus.Interface(self.bus.get_object(NAME, OBJECT), NAME)
            wanted_claim = self.screen_on and not read_json(PREFERENCE).get('locked', False)
            if wanted_claim and not self.claimed:
                self.proxy.ClaimAccelerometer(timeout=5)
                self.claimed = True
                props = self.dbus.Interface(self.bus.get_object(NAME, OBJECT),
                                            'org.freedesktop.DBus.Properties')
                self.orientation = str(props.Get(NAME, 'AccelerometerOrientation'))
                logging.info('Accelerometer claimed')
            elif not wanted_claim and self.claimed:
                self.proxy.ReleaseAccelerometer(timeout=5)
                self.claimed = False
                logging.info('Accelerometer released')
        except Exception as error:
            # Retry service discovery/claim every five seconds without log spam.
            if self.tick_count % 5 == 1:
                logging.warning('Sensor unavailable: %s', error)
            self.proxy, self.claimed = None, False
        self.update()
        return True

    def run(self):
        self.tick()
        self.glib.timeout_add_seconds(1, self.tick)
        self.glib.MainLoop().run()


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    for name in ('toggle', 'lock', 'unlock', 'portrait', 'status'):
        group.add_argument('--' + name, action='store_true')
    args = parser.parse_args()
    if args.status:
        print(json.dumps(read_json(STATE), indent=2))
        return
    if args.toggle or args.lock or args.unlock or args.portrait:
        old = read_json(PREFERENCE)
        locked = not old.get('locked', False) if args.toggle else not args.unlock
        current = read_json(STATE).get('applied')
        orientation = 'normal' if args.portrait else current
        if orientation not in MODES:
            orientation = 'normal'
        write_json(PREFERENCE, dict(locked=locked, orientation=orientation))
        print('Rotation locked' if locked else 'Automatic rotation enabled')
        return
    CACHE.mkdir(mode=0o700, parents=True, exist_ok=True)
    with (CACHE / 'daemon.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        handler = RotatingFileHandler(CACHE / 'rotation.log', maxBytes=131072, backupCount=1)
        logging.basicConfig(level=logging.INFO, handlers=[handler],
                            format='%(asctime)s %(levelname)s %(message)s')
        if not os.environ.get('DISPLAY'):
            logging.error('No X display; launch from the desktop session')
            return
        Rotation().run()


if __name__ == '__main__':
    main()
