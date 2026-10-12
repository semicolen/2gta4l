#!/usr/bin/env python3
from pathlib import Path
import hashlib
import re

workspace = Path(__file__).resolve().parents[1]
archive = workspace / 'firmware-local/gta4l-firmware-T505XXS8CXG1.tar.gz'
digest = hashlib.file_digest(archive.open('rb'), 'sha512').hexdigest()
apk = workspace / 'port/firmware-samsung-gta4l/APKBUILD'
text, count = re.subn(r'^[0-9a-f]{128}  gta4l-firmware-T505XXS8CXG1\.tar\.gz$', digest + '  gta4l-firmware-T505XXS8CXG1.tar.gz', apk.read_text(), flags=re.M)
assert count == 1, 'Unexpected firmware checksum block'
apk.write_text(text, newline='\n')
