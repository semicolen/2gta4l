#!/usr/bin/env python3
"""Apply Linux userspace requirements without discarding Samsung drivers."""
from pathlib import Path
import hashlib
import re

root = Path(__file__).resolve().parents[1]
cfg = root / 'port/linux-samsung-gta4l/config-samsung-gta4l.aarch64'
text = cfg.read_text()
values = {
    'DEVTMPFS_MOUNT': 'y', 'FHANDLE': 'y', 'PID_NS': 'y',
    'DRM_FBDEV_EMULATION': 'y', 'FRAMEBUFFER_CONSOLE': 'y',
    'FRAMEBUFFER_CONSOLE_ROTATION': 'y', 'USB_CONFIGFS_ECM': 'y',
    'USB_CONFIGFS_RNDIS': 'y', 'MODULE_SIG_FORCE': 'n', 'MODULE_SIG_ALL': 'n',
    'STATIC_USERMODEHELPER': 'n', 'FW_LOADER_USER_HELPER_FALLBACK': 'n',
    'SECURITY_SELINUX': 'n', 'SECURITY_SMACK': 'n',
    'QCA_CLD_WLAN': 'm', 'FW_LOADER': 'y', 'IKCONFIG_PROC': 'y',
    'BT_HCIUART': 'y', 'BT_HCIUART_H4': 'y', 'BT_HCIUART_QCA': 'y',
    'SERIAL_DEV_BUS': 'y', 'SERIAL_DEV_CTRL_TTYPORT': 'y', 'BT_HCIUART_SERDEV': 'y',
    'BT_BNEP': 'm', 'BT_BNEP_MC_FILTER': 'y', 'BT_BNEP_PROTO_FILTER': 'y',
    'BT_HIDP': 'm', 'HIDRAW': 'y', 'UHID': 'y',
}
for key, value in values.items():
    pattern = rf'^(?:CONFIG_{key}=.*|# CONFIG_{key} is not set)$'
    replacement = f'# CONFIG_{key} is not set' if value == 'n' else f'CONFIG_{key}={value}'
    if re.search(pattern, text, re.M):
        text = re.sub(pattern, replacement, text, flags=re.M)
    else:
        text += '\n' + replacement + '\n'
cfg.write_text(text, newline='\n')
# Linux packaging checks require LF, including files initially copied via Windows.
for local in (root / 'port').rglob('*'):
    if local.is_file():
        data = local.read_bytes()
        # Stock runtime archives and compiled objects must remain byte-exact.
        # Normalize only UTF-8 text, never binary files that happen to contain
        # the CRLF byte pair.
        if b'\0' in data:
            continue
        try:
            data.decode('utf-8')
        except UnicodeDecodeError:
            continue
        if b'\r\n' in data:
            local.write_bytes(data.replace(b'\r\n', b'\n'))
# Refresh only local source checksums; preserve the verified upstream archive hash.
for package in (root / 'port').iterdir():
    apk = package / 'APKBUILD'
    if not apk.exists():
        continue
    text = apk.read_text()
    def update(match):
        local = package / match[2]
        if local.is_file():
            return hashlib.sha512(local.read_bytes()).hexdigest() + '  ' + match[2]
        return match[0]
    text = re.sub(r'^([0-9a-f]{128})  (\S+)$', update, text, flags=re.M)
    # Newly added local source files also need a checksum entry.
    source_block = re.search(r'^source="(.*?)"', text, re.M | re.S)
    if source_block:
        for name in source_block[1].split():
            local = package / name
            if local.is_file() and not re.search(rf'^[0-9a-f]{{128}}  {re.escape(name)}$', text, re.M):
                digest = hashlib.sha512(local.read_bytes()).hexdigest()
                text = text.rstrip()
                assert text.endswith('"'), f'Missing trailing checksum block: {apk}'
                text = text[:-1] + digest + '  ' + name + '\n"\n'
    apk.write_text(text, newline='\n')
