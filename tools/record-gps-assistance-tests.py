#!/usr/bin/env python3
"""Keep the completed Meson summary; abuild removes its source tree afterward."""
from pathlib import Path
import re,argparse
parser=argparse.ArgumentParser();parser.add_argument('--revision',type=int,choices=(4,5),default=4)
revision=parser.parse_args().revision
workspace=Path(__file__).resolve().parents[1]
text=(workspace/f'logs/modemmanager-assistance-r{revision}-build.log').read_text()
marker=f'>>> modemmanager: Building pmos/modemmanager 1.25.95_git20261005-r{revision} '
start=text.rfind(marker);assert start>=0
text=text[start:]
begin=re.search(r'(?m)^\s*1/38 ModemManager:',text);assert begin
end=text.index('\n',text.index('Full log written to ',begin.start()))
result=text[begin.start():end]+'\n'
assert re.search(r'Ok:\s+38',result) and re.search(r'Fail:\s+0',result)
assert '>>> modemmanager: Build complete' in text
(workspace/f'logs/modemmanager-assistance-r{revision}-tests.log').write_text(result)
print(f'ModemManager assistance r{revision}: 38 upstream tests passed; completed local build recorded')
