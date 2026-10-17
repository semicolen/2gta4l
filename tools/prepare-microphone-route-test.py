#!/usr/bin/env python3
"""Select one matching-stock route for the reversible capture diagnostic."""
from pathlib import Path
import argparse
parser=argparse.ArgumentParser();parser.add_argument('--route',choices=('qrd','qrd-gain','qrd-main','dmic0','dmic2'),required=True)
parser.add_argument('--seconds',type=int,choices=range(4,13),default=4)
args=parser.parse_args();route=args.route
workspace=Path(__file__).resolve().parents[1]
text=(workspace/'diagnostics/ui-qc-microphone-stock-route-test.sh').read_text()
assert text.count("route_name='dmic2'")==1
text=text.replace("route_name='dmic2'",f"route_name='{route}'")
text=text.replace('capture_seconds=4',f'capture_seconds={args.seconds}')
out=workspace/'artifacts/diagnostics'/f'microphone-{route}.sh';out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(text,newline='\n')
print('Prepared reversible stock microphone route:',route)
