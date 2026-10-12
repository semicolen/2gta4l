#!/usr/bin/env python3
"""Decode a saved kernel pstore deflate record without changing its source."""
from pathlib import Path
import argparse
import zlib

parser = argparse.ArgumentParser()
parser.add_argument('source', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
data = args.source.read_bytes()
for window in [zlib.MAX_WBITS, -zlib.MAX_WBITS, zlib.MAX_WBITS + 16]:
    try:
        # crypto/deflate.c documents a raw-deflate workaround: one extra
        # zero byte may be needed for the decoder to recognize stream end.
        decoded = zlib.decompress(data + b'\0', window)
    except zlib.error as error:
        print(f'window={window}: {error}')
        continue
    args.output.write_bytes(decoded)
    print(f'Decoded {len(data)} bytes to {len(decoded)} bytes, window={window}')
    break
else:
    raise SystemExit(f'Unable to decode pstore record; first bytes={data[:16].hex()}')
