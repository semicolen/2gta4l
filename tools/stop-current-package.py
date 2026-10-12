"""Stop only this task's premature local packaging process."""
from pathlib import Path
import os,signal
directory=Path(__file__).resolve().parent
target=str(directory/'package-current-recovery.py').encode()
child=str(directory/'package-recovery.py').encode()
for path in Path('/proc').iterdir():
    if not path.name.isdigit():continue
    try:args=(path/'cmdline').read_bytes().split(b'\0')
    except FileNotFoundError:continue
    parent=len(args)>=2 and args[0]==b'python3' and args[1]==target
    related_child=(len(args)>=2 and args[0]==b'python3' and args[1]==child
        and b'--package-revision' in args and b'3' in args
        and any(a.endswith(b'/postmarketOS-SM-T505-OrangeFox-bringup-r3.zip') for a in args))
    if parent or related_child:
        os.kill(int(path.name),signal.SIGTERM)
        print('Stopped premature packaging PID '+path.name)
