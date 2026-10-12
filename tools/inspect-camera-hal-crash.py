"""Disassemble the matched stock HAL around the observed initialization fault."""
from pathlib import Path
import shutil
import subprocess

workspace = Path(__file__).resolve().parents[1]
native = Path('/home/pmos/sm-t505-port/work/chroot_native')
target = native/'tmp/gta4l-camera-build/camera.qcom.so'
shutil.copyfile(workspace/'evidence/stock-camera/camera.qcom.so', target)
text = subprocess.check_output(['chroot', str(native), '/usr/bin/llvm-objdump',
    '-d', '--demangle', '--start-address=0x321d80', '--stop-address=0x321f40',
    '/tmp/gta4l-camera-build/camera.qcom.so'], text=True)
(workspace/'evidence/stock-camera/init-crash.disassembly').write_text(text)
print(text)
