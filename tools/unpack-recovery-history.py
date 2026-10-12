#!/usr/bin/env python3
from pathlib import Path
import gzip

root = Path(__file__).resolve().parents[1] / 'evidence/bootloop-20261009'
for name in ['log.gz', 'last_log.gz']:
    source = root / name
    (root / (name + '.txt')).write_bytes(gzip.decompress(source.read_bytes()))
