#!/usr/bin/env python3
"""Select a physical lens and optionally the temporary compiled candidate."""
from pathlib import Path
import argparse
parser=argparse.ArgumentParser();parser.add_argument('--camera',choices=('rear','front'),required=True)
parser.add_argument('--candidate',action='store_true');args=parser.parse_args()
workspace=Path(__file__).resolve().parents[1]
text=(workspace/'diagnostics/ui-qc-snapshot-photo-stress.sh').read_text()
name='Galaxy Tab A7 '+args.camera.title()+' Camera'
text=text.replace("camera_name=''",f"camera_name='{name}'")
if args.candidate:text=text.replace("app_command=['/usr/sbin/snapshot']","app_command=['/run/gta4l-snapshot-candidate/snapshot']")
out=workspace/'artifacts/diagnostics'/f'snapshot-{args.camera}-stress.sh';out.write_text(text,newline='\n')
print('NATIVE_CAMERA_LENS_STRESS_PREPARED',args.camera,'candidate',args.candidate)
