#!/usr/bin/env python3
"""Check completed UI receipts against their rootfs and publish the local index."""
from pathlib import Path
import json
workspace=Path(__file__).resolve().parents[1]
base=Path('/home/pmos/sm-t505-port/ui-work')
output=workspace/'artifacts/ui-builds'
profiles=json.loads((workspace/'ui-profiles/profiles.json').read_text())
reports=[]
for ui,profile in profiles.items():
    path=output/(ui+'-verification.json')
    report=json.loads(path.read_text())
    root=base/ui/'chroot_rootfs_samsung-gta4l'
    root_report=json.loads((output/(ui+'-rootfs-verification.json')).read_text())
    installer=json.loads((output/(ui+'-installer-verification.json')).read_text())
    records={}
    for section in (root/'lib/apk/db/installed').read_text().split('\n\n'):
        values=dict(line.split(':',1) for line in section.splitlines() if ':' in line)
        if 'P' in values:records[values['P']]=values['V']
    assert 'openrc' in records and 'postmarketos-base-openrc' in records
    assert 'systemd' not in records and 'postmarketos-base-systemd' not in records
    assert 'postmarketos-base-ui-audio-backend-pulseaudio' in records and 'pipewire-pulse' not in records
    assert all(name in records for name in profile['core_packages'])
    assert root_report['checks_passed'] and root_report['ui']==ui
    assert installer['zip_crc_checks_passed'] and installer['embedded_boot_matches']
    assert installer['embedded_module_loader_matches'] and installer['package_revision']==5
    assert report['packaging_schema']==2 and report['embedded_modules_verified']==37
    assert report['embedded_apk_database_verified'] and report['apk_signing_keys_verified']
    assert report['formats_userdata'] and not report['rootfs_runtime_verified']
    assert not report['installer_flashing_verified']
    assert (output/report['package']).stat().st_size==report['bytes']
    report['desktop_packages']={name:records[name] for name in profile['core_packages']}
    assert report['desktop_packages']==root_report['desktop_packages']
    report['session_descriptors']=root_report['session_descriptors']
    report['ui_overlay_sha256']=root_report.get('ui_overlay_sha256',{})
    report['init_system']='OpenRC'
    if ui=='sxmo-de-sway':
        assert (root/'etc/runlevels/default/seatd').is_symlink()
        assert (root/'etc/init.d/seatd').is_file()
        assert {'seat','input'}.issubset({line.split(':')[0] for line in (root/'etc/group').read_text().splitlines() if 'tablet' in line.split(':')[3].split(',')})
        report['seatd_enabled_verified']=True
    path.write_text(json.dumps(report,indent=2)+'\n')
    reports.append(report)
assert len(reports)==6 and len({row['boot_sha256'] for row in reports})==1
(output/'index.json').write_text(json.dumps({'device':'SM-T505','build_host':'WSL Ubuntu','profiles':reports},indent=2)+'\n')
(output/'SHA256SUMS').write_text(''.join(row['sha256']+'  '+row['package']+'\n' for row in reports))
print('ALL_SIX_UI_BUILD_RECEIPTS_VERIFIED')
for row in reports:print(row['ui']+': '+str(row['bytes'])+' bytes '+row['sha256'])
