#!/usr/bin/env python3
"""Read microphone routes from the matching local Samsung references."""
from pathlib import Path
import xml.etree.ElementTree as ET
workspace=Path(__file__).resolve().parents[1]
for name in ('mixer_paths.xml','mixer_paths_qrd.xml','wt_cust_audio.xml'):
    tree=ET.parse(workspace/'evidence/stock-audio'/name)
    paths={p.get('name'):p for p in tree.getroot().findall('path')}
    print('STOCK_MICROPHONE_REFERENCE',name)
    selected=[n for n in paths if n in ('audio-record','handset-mic','camcorder-mic','speaker-mic','voice-rec-mic','handset-dmic','camcorder-dmic')]
    def show(name,seen):
        if name in seen:return
        seen.add(name);p=paths.get(name)
        if p is None:return
        print(ET.tostring(p,encoding='unicode'))
        for child in p.findall('path'):show(child.get('name'),seen)
    seen=set()
    for name in selected:show(name,seen)
