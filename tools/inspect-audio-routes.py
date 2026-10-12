#!/usr/bin/env python3
from pathlib import Path
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
for name in ['mixer_paths_qrd.xml', 'audio_platform_info_qrd.xml']:
    tree = ET.parse(root / 'evidence/stock-audio' / name)
    print('REFERENCE', name)
    if name.startswith('mixer'):
        for path in tree.getroot().findall('path'):
            if path.get('name') in ['speaker', 'deep-buffer-playback speaker',
                    'low-latency-playback speaker', 'headphones', 'handset',
                    'audio-record', 'handset-mic', 'deep-buffer-playback']:
                print(ET.tostring(path, encoding='unicode'))
    else:
        for elem in tree.getroot().iter():
            if any('SPEAKER' in value for value in elem.attrib.values()):
                print(elem.tag, elem.attrib)
raw = (root / 'evidence/diagnostic-boot-20261009/device-r13-audio-route-state.raw').read_text()
print('CURRENT SELECTED CONTROLS')
for block in re.split(r'(?=^numid=)', raw, flags=re.M):
    first = block.splitlines()[0] if block else ''
    if re.search(r"FSM|MI2S_RX (?:Channels|Format|SampleRate)|MI2S_RX Audio Mixer MultiMedia1'|Playback 0 Volume", first):
        print(block.split('=== Audio services ===')[0])
print(raw[raw.index('=== Audio services ==='):])
