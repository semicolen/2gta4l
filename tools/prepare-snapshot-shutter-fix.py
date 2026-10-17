#!/usr/bin/env python3
"""Keep Alpine's versioned recipe and fix Snapshot's shutter-player lifetime."""
from pathlib import Path
import difflib,hashlib,re,urllib.request
workspace=Path(__file__).resolve().parents[1]
reference=workspace/'downloads/camera-pipewire-reference'
package=workspace/'port/snapshot';package.mkdir(exist_ok=True)
recipe=(reference/'snapshot-APKBUILD').read_text()
assert 'pkgver=51.0\n' in recipe and 'pkgrel=0\n' in recipe
for name in ('cargo-auditable.patch','rustix.patch'):
    data=urllib.request.urlopen('https://raw.githubusercontent.com/alpinelinux/aports/master/community/snapshot/'+name,timeout=25).read()
    digest=re.search(r'^([0-9a-f]{128})  '+re.escape(name)+r'$',recipe,re.M)[1]
    assert hashlib.sha512(data).hexdigest()==digest
    (package/name).write_bytes(data)
old=(reference/'snapshot-camera-widget.rs').read_text()
before='''        // If we don't hold a reference to it there is a condition race which
        // will cause the sound to play only sometimes.
        let resource = "/org/gnome/Snapshot/sounds/camera-shutter.wav";
        let player = gtk::MediaFile::for_resource(resource);
        player.play();

        self.imp().players.replace(Some(player));'''
after='''        // Reuse the player instead of destroying a media playback context
        // while the viewfinder's renderer is active. Retaining it also keeps
        // the sound alive until playback finishes.
        let imp = self.imp();
        let mut players = imp.players.borrow_mut();
        if let Some(player) = players.as_ref() {
            player.pause();
            player.seek(0);
            player.play();
            return;
        }

        let resource = "/org/gnome/Snapshot/sounds/camera-shutter.wav";
        let player = gtk::MediaFile::for_resource(resource);
        player.play();
        players.replace(player);'''
assert old.count(before)==1
new=old.replace(before,after)
patch=''.join(difflib.unified_diff(old.splitlines(keepends=True),new.splitlines(keepends=True),fromfile='a/src/widgets/camera.rs',tofile='b/src/widgets/camera.rs'))
(package/'reuse-shutter-player.patch').write_text(patch,newline='\n')
recipe=recipe.replace('pkgrel=0\n','pkgrel=1\n').replace('\trustix.patch\n','\trustix.patch\n\treuse-shutter-player.patch\n\tcrossdirect-auditable-cargo\n',1)
recipe=recipe.replace('build() {\n','''build() {
\tif [ "${PMB_CROSS:-}" = crossdirect ]; then
\t\tmkdir -p "$srcdir/cargo-crossdirect"
\t\tinstall -m755 "$srcdir/crossdirect-auditable-cargo" "$srcdir/cargo-crossdirect/cargo"
\t\texport PATH="$srcdir/cargo-crossdirect:$PATH"
\tfi
''')
digest=hashlib.sha512(patch.encode()).hexdigest()
recipe=recipe.rstrip();assert recipe.endswith('"')
wrapper_hash=hashlib.sha512((package/'crossdirect-auditable-cargo').read_bytes()).hexdigest()
recipe=recipe[:-1]+digest+'  reuse-shutter-player.patch\n'+wrapper_hash+'  crossdirect-auditable-cargo\n"\n'
(package/'APKBUILD').write_text(recipe,newline='\n')
print('SNAPSHOT_51_R1_TARGETED_SHUTTER_PLAYER_PATCH_PREPARED')
