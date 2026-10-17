"""Save the latest completed ModemManager test summary before the next build."""
from pathlib import Path
import re

ws=Path('/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os')
text=(ws/'logs/modemmanager-gps-build.log').read_text()
marker='>>> modemmanager: Building pmos/modemmanager 1.25.95_git20261005-r3 '
start=text.rfind(marker)
assert start>=0
text=text[start:]
test_start=re.search(r'(?m)^\s*1/38 ModemManager:',text).start()
test_end=text.index('\n',text.index('Full log written to ',test_start))
result='ModemManager 1.25.95_git20261005-r3; built locally in WSL Ubuntu\n'+text[test_start:test_end]+'\n'
assert re.search(r'Ok:\s+38',result) and re.search(r'Fail:\s+0',result)
(ws/'logs/modemmanager-gps-tests.log').write_text(result)
print('Saved the direct-QMI build test summary: 38 passed, 0 failed')
