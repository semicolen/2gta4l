#!/usr/bin/env python3
"""Record the user's phone-SIM mobile data confirmation without device writes."""
from pathlib import Path
import json
workspace=Path(__file__).resolve().parents[1]
publication=workspace/'.publication/2gta4l'
old='limited/searching service with the experimental SIM, no active data plan; mobile internet unverified'
new='mobile data is user-confirmed working on 2026-10-13 after inserting a phone SIM; earlier limited/searching service used an experimental SIM with no data plan; calls, SMS and data reconnection after reboot remain unverified; see LTE-REPORT.md'
for root in (workspace,publication):
    path=root/'PORT-STATUS.md';text=path.read_text();assert old in text
    path.write_text(text.replace(old,new),encoding='utf8',newline='\n')
    path=root/'README.md';text=path.read_text()
    old_readme='photo saving, preview restart and correct colors pass. Camera recording,\nLTE data, microphone/headset routing, charging, suspend and remaining\nsensors need further work.'
    new_readme='photo saving, preview restart and correct colors pass. Mobile data is\nuser-confirmed working with a phone SIM; see [LTE-REPORT.md](LTE-REPORT.md).\nCamera recording, microphone/headset routing, charging, suspend and remaining\nsensors need further work.'
    assert old_readme in text;text=text.replace(old_readme,new_readme)
    old_modem='storage for the first tests. Enabling persistent modem writes and checking\nLTE data routing are subsequent device validation steps.'
    new_modem='storage for the first tests. Mobile data is now user-confirmed working with\na phone SIM. Persistent modem storage writes remain unverified.'
    assert old_modem in text;text=text.replace(old_modem,new_modem)
    path.write_text(text,encoding='utf8',newline='\n')
    path=root/'CURRENT-BUILD.md';text=path.read_text()
    old_current='camera access and microphone/headset routing also remain unverified. LTE modem discovery works,\nbut mobile data needs an active plan to validate. Desktop OpenGL uses software'
    new_current='camera access and microphone/headset routing also remain unverified. Mobile\ndata is user-confirmed working with a phone SIM on 13 October 2026; see\n`LTE-REPORT.md`. Calls and SMS remain unverified. Desktop OpenGL uses software'
    assert old_current in text
    path.write_text(text.replace(old_current,new_current),encoding='utf8',newline='\n')
(publication/'LTE-REPORT.md').write_bytes((workspace/'LTE-REPORT.md').read_bytes())
report={'device':'SM-T505','reported_date':'2026-10-13','timezone':'Europe/Stockholm',
        'feature':'mobile data','status':'working','verification':'user confirmation',
        'test':'User inserted phone SIM into the installed postmarketOS tablet and reported working mobile data',
        'installed_kernel_release':9,'automated_mobile_internet_test':False,
        'radio_access_technology_recorded':False,'calls_verified':False,'sms_verified':False,
        'fresh_ui_candidates_tested':False}
(workspace/'artifacts/lte-user-verification.json').write_text(json.dumps(report,indent=2)+'\n')
(publication/'validation/lte-user-verification.json').write_text(json.dumps(report,indent=2)+'\n')
print('LTE_USER_CONFIRMATION_RECORDED')
