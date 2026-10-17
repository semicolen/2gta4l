#!/usr/bin/env python3
"""Apply tablet-tested compatibility settings to an isolated WSL UI rootfs."""
from pathlib import Path
import hashlib
import json
import os
import re
import shutil


def apply(root: Path, ui: str, workspace: Path) -> dict[str, str]:
    overlays = {}
    records = {}
    for section in (root / 'lib/apk/db/installed').read_text().split('\n\n'):
        values = dict(line.split(':', 1) for line in section.splitlines() if ':' in line)
        if 'P' in values:
            records[values['P']] = values['V']
    # Every image uses elogind. The ConsoleKit variant cannot identify its seat.
    assert 'polkit-elogind' in records and 'polkit-elogind-libs' in records
    assert 'polkit-noelogind-libs' not in records
    if ui in ('plasma-mobile', 'plasma-desktop'):
        source = workspace / 'ui-profiles/plasma-kcminputrc'
        target = root / 'etc/skel/.config/kcminputrc'
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        target.chmod(0o644)
        os.chown(target, 0, 0)
        overlays[str(target.relative_to(root))] = hashlib.sha256(target.read_bytes()).hexdigest()
        source_mode=workspace/'ui-profiles/plasma-kwinrc'
        mode=root/'etc/skel/.config/kwinrc'
        shutil.copyfile(source_mode,mode)
        mode.chmod(0o644)
        os.chown(mode,0,0)
        overlays[str(mode.relative_to(root))]=hashlib.sha256(mode.read_bytes()).hexdigest()
        if ui == 'plasma-desktop':
            account = next(line.split(':') for line in (root/'etc/passwd').read_text().splitlines()
                           if line.startswith('sddm:'))
            target = root/account[5].lstrip('/')/'.config/kcminputrc'
            target.parent.mkdir(parents=True, exist_ok=True)
            os.chown(target.parent, int(account[2]), int(account[3]))
            shutil.copyfile(source, target)
            target.chmod(0o644)
            os.chown(target, int(account[2]), int(account[3]))
            overlays[str(target.relative_to(root))] = hashlib.sha256(target.read_bytes()).hexdigest()
            assert records['mesa-zink-kgsl-gta4l']=='26.0.8-r3'
            # Retain a software greeter and fallback; select GPU only in Plasma.
            for name,destination in (
                ('plasma-rendering-profile.sh','etc/profile.d/80-gta4l-rendering.sh'),
                ('plasma-zink-environment.sh','etc/skel/.config/plasma-workspace/env/80-gta4l-zink.sh')):
                path=root/destination
                path.parent.mkdir(parents=True,exist_ok=True)
                shutil.copyfile(workspace/'ui-profiles'/name,path)
                path.chmod(0o700 if name=='plasma-zink-environment.sh' else 0o644);os.chown(path,0,0)
                overlays[destination]=hashlib.sha256(path.read_bytes()).hexdigest()
            session=root/'usr/share/wayland-sessions/plasma.desktop'
            original=session.read_text().replace('Exec=/usr/bin/gta4l-zink-run /usr/lib/libexec/plasma-dbus-run-session-if-needed',
                                                 'Exec=/usr/lib/libexec/plasma-dbus-run-session-if-needed')
            assert 'Exec=/usr/lib/libexec/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland' in original
            fallback=session.with_name('plasma-gta4l-software.desktop')
            fallback.write_text(re.sub(r'^(Name(?:\[[^\]]+\])?)=.*$',r'\1=Plasma (Software fallback)',original,flags=re.M))
            session.write_text(original.replace('Exec=/usr/lib/libexec/plasma-dbus-run-session-if-needed',
                                                'Exec=/usr/bin/gta4l-zink-run /usr/lib/libexec/plasma-dbus-run-session-if-needed'))
            # Fresh recovery images have no previous login to select a session.
            state=root/'var/lib/sddm/state.conf'
            state.parent.mkdir(parents=True,exist_ok=True)
            state.write_text('[Last]\nSession=/usr/share/wayland-sessions/plasma.desktop\nUser=tablet\n')
            state.chmod(0o600);os.chown(state,int(account[2]),int(account[3]))
            for path in (session,fallback,state):
                overlays[str(path.relative_to(root))]=hashlib.sha256(path.read_bytes()).hexdigest()
    if ui in ('gnome', 'gnome-mobile'):
        # Override the device's Xfce identity rule for Mutter, including GDM.
        source=workspace/'ui-profiles/99-gta4l-gnome-touch.rules'
        target=root/'etc/udev/rules.d'/source.name
        shutil.copyfile(source,target)
        target.chmod(0o644);os.chown(target,0,0)
        overlays[str(target.relative_to(root))]=hashlib.sha256(target.read_bytes()).hexdigest()
        assert records['mesa-zink-kgsl-gta4l']=='26.0.8-r3'
        wrapper=root/'usr/bin/gta4l-gnome-session'
        shutil.copyfile(workspace/'ui-profiles/gta4l-gnome-session',wrapper)
        wrapper.chmod(0o755);os.chown(wrapper,0,0)
        profile=root/'etc/profile.d/80-gta4l-rendering.sh'
        shutil.copyfile(workspace/'ui-profiles/gnome-rendering-profile.sh',profile)
        profile.chmod(0o644);os.chown(profile,0,0)
        session=root/'usr/share/wayland-sessions/gnome.desktop'
        original=session.read_text().replace('Exec=/usr/bin/gta4l-zink-run /usr/bin/gta4l-gnome-session','Exec=/usr/bin/gnome-session')
        original=original.replace('Exec=/usr/bin/gta4l-zink-run /usr/bin/gnome-session','Exec=/usr/bin/gnome-session')
        assert re.search(r'^Exec=/usr/bin/gnome-session\s*$',original,re.M)
        fallback=session.with_name('gnome-gta4l-software.desktop')
        fallback_text=re.sub(r'^(Name(?:\[[^\]]+\])?)=.*$',r'\1=GNOME (Software fallback)',original,flags=re.M)
        fallback.write_text(re.sub(r'^Exec=/usr/bin/gnome-session\s*$',
                                  'Exec=/usr/bin/gta4l-gnome-session',fallback_text,flags=re.M))
        session.write_text(re.sub(r'^Exec=/usr/bin/gnome-session\s*$',
                                 'Exec=/usr/bin/gta4l-zink-run /usr/bin/gta4l-gnome-session',original,flags=re.M))
        overlays[str(wrapper.relative_to(root))]=hashlib.sha256(wrapper.read_bytes()).hexdigest()
        for path in (profile,session,fallback):
            path.chmod(0o644);os.chown(path,0,0)
            overlays[str(path.relative_to(root))]=hashlib.sha256(path.read_bytes()).hexdigest()
    # The initramfs/base USB setup already supplies the tested RNDIS gadget.
    # The mobile USB controller removed that connection when the desktop started.
    if ui in ('plasma-mobile', 'gnome-mobile', 'gnome'):
        target = root / 'etc/runlevels/default/usb-signaller'
        if target.is_symlink():
            assert (os.readlink(target) == '/etc/init.d/usb-signaller' or
                    target.resolve() == root / 'etc/init.d/usb-signaller')
            target.unlink()
        assert not target.exists()
    if ui in ('plasma-mobile','plasma-desktop','gnome-mobile','gnome'):
        source=workspace/'ui-profiles/82-gta4l-wayland-sensors.rules'
        target=root/'etc/udev/rules.d'/source.name
        shutil.copyfile(source,target)
        target.chmod(0o644)
        os.chown(target,0,0)
        overlays[str(target.relative_to(root))]=hashlib.sha256(target.read_bytes()).hexdigest()
    receipt = root / 'etc/gta4l-ui-compat.json'
    receipt.write_text(json.dumps({
        'ui': ui, 'revision': 6, 'polkit_provider': 'elogind',
        'gnome_touch_calibration': ui in ('gnome','gnome-mobile'),
        'gnome_adreno_rendering': ui in ('gnome','gnome-mobile'),
        'gnome_gtk_opengl': ui in ('gnome','gnome-mobile'),
        'plasma_adreno_rendering': ui=='plasma-desktop',
        'plasma_touch_calibration': ui in ('plasma-mobile', 'plasma-desktop'),
        'sddm_touch_calibration': ui == 'plasma-desktop',
        'plasma_tablet_mode': ui in ('plasma-mobile','plasma-desktop'),
        'native_wayland_sensor_axes': ui in ('plasma-mobile','plasma-desktop','gnome-mobile','gnome'),
        'retain_base_usb_gadget': ui in ('plasma-mobile', 'gnome-mobile', 'gnome'),
    }, indent=2) + '\n')
    receipt.chmod(0o644)
    os.chown(receipt, 0, 0)
    overlays[str(receipt.relative_to(root))] = hashlib.sha256(receipt.read_bytes()).hexdigest()
    return overlays
