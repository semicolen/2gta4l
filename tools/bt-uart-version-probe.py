#!/usr/bin/env python3
"""Bounded volatile UART power/version probe; never installs a line discipline."""
from pathlib import Path
import fcntl
import os
import select
import stat
import struct
import termios
import time

device = Path('/dev/ttyHS0')
assert stat.S_ISCHR(device.stat().st_mode)
assert '4a8c000' in str(Path('/sys/class/tty/ttyHS0/device').resolve())
radio = Path('/sys/class/rfkill/rfkill0')
assert (radio / 'name').read_text().strip() == 'bt_power'
was_blocked = (radio / 'soft').read_text().strip()
fd = None
original = None
try:
    (radio / 'soft').write_text('0\n')
    time.sleep(0.2)
    fd = os.open(device, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    fcntl.ioctl(fd, termios.TIOCEXCL)
    discipline = struct.unpack('i', fcntl.ioctl(fd, termios.TIOCGETD, struct.pack('i', 0)))[0]
    assert discipline == 0, 'UART already has an active line discipline'
    original = termios.tcgetattr(fd)

    def configure(baud, flow):
        settings = termios.tcgetattr(fd)
        settings[0] = settings[1] = settings[3] = 0
        settings[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
        if flow:
            settings[2] |= termios.CRTSCTS
        settings[4] = settings[5] = baud
        settings[6][termios.VMIN] = settings[6][termios.VTIME] = 0
        termios.tcsetattr(fd, termios.TCSANOW, settings)
        modem = struct.unpack('I', fcntl.ioctl(fd, termios.TIOCMGET, struct.pack('I', 0)))[0]
        flags = termios.TIOCM_RTS | getattr(termios, 'TIOCM_OUT2', 0x4000)
        modem = modem | flags if flow else modem & ~flags
        fcntl.ioctl(fd, termios.TIOCMSET, struct.pack('I', modem))

    def send(data):
        remaining = memoryview(data)
        deadline = time.monotonic() + 2
        while remaining and time.monotonic() < deadline:
            if not select.select([], [fd], [], 0.2)[1]:
                continue
            try:
                count = os.write(fd, remaining)
            except BlockingIOError:
                continue
            remaining = remaining[count:]
        assert not remaining, 'UART transmit timed out'

    # The matching downstream WCN3990 power-on sequence uses 0xc0 at
    # 2400 baud and 0xfc at 115200 baud with hardware flow disabled.
    configure(termios.B2400, False)
    send(b'\xc0')
    time.sleep(0.1)
    configure(termios.B115200, False)
    send(b'\xfc')
    time.sleep(0.15)
    os.close(fd)
    fd = os.open(device, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    fcntl.ioctl(fd, termios.TIOCEXCL)
    configure(termios.B115200, True)
    termios.tcflush(fd, termios.TCIFLUSH)
    # H4 command framing: QCA EDL_PATCH_CMD_OPCODE 0xfc00,
    # EDL_PATCH_VER_REQ_CMD 0x19. This only requests ROM/version data.
    send(bytes.fromhex('01 00 fc 01 19'))
    received = bytearray()
    deadline = time.monotonic() + 3
    while time.monotonic() < deadline and len(received) < 256:
        if select.select([fd], [], [], 0.2)[0]:
            try:
                received.extend(os.read(fd, 256-len(received)))
            except BlockingIOError:
                pass
    print('BT_UART_VERSION_REPLY=' + received.hex())
    print('BT_UART_VERSION_BYTES=' + str(len(received)))
finally:
    if fd is not None:
        if original is not None:
            termios.tcsetattr(fd, termios.TCSANOW, original)
        os.close(fd)
    (radio / 'soft').write_text(was_blocked + '\n')
    print('BT_RFKILL_STATE_RESTORED=' + was_blocked)
