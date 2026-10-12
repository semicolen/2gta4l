#!/usr/bin/python3
"""Initialize the SM-T505 WCN3988 UART with stock firmware in controller RAM.

The kernel's QCA tty setup dereferences a missing serdev object. Bootstrap in
userspace, disable IBS in the downloaded NVM, and use the standard H4 transport.
Calibration partitions and the installed firmware files are never written.
"""
from pathlib import Path
import argparse
import fcntl
import hashlib
import os
import re
import select
import signal
import stat
import struct
import subprocess
import termios
import time

PATCH_SHA = '769dd959feddf8f1ddbf90cdad4acf24e6fe3340a987c1215a68b1a50e652e93'
NVM_SHA = 'cf752b5068193a93d0767678f8f732cc0edd6c9b71c6b52852dc9551a0bfc6e4'
EXPECTED_VERSION = (0x0a, 0x0201, 0x40020150)


def log(message):
    print(message, flush=True)


def checked_tlv(data, kind):
    assert len(data) >= 4
    header = struct.unpack_from('<I', data)[0]
    assert header & 255 == kind and header >> 8 == len(data)-4, 'Invalid TLV container'
    return data[4:]


def stock_address():
    partitions = []
    for entry in Path('/sys/class/block').glob('mmcblk0p*/uevent'):
        values = dict(line.split('=', 1) for line in entry.read_text().splitlines() if '=' in line)
        if values.get('PARTNAME') == 'sec_efs':
            partitions.append('/dev/'+values['DEVNAME'])
    assert partitions == ['/dev/mmcblk0p63'], 'Unexpected SM-T505 calibration partition'
    assert stat.S_ISBLK(Path(partitions[0]).stat().st_mode)
    # debugfs without -w opens the partition read-only. No mount or journal
    # replay is needed, and the unique address is never printed in the log.
    result = subprocess.run(['/usr/sbin/debugfs', '-R', 'cat /bluetooth/bt_addr', partitions[0]],
                            capture_output=True, check=True, timeout=4)
    assert len(result.stdout) <= 256
    raw = result.stdout.strip(b'\x00\r\n ')
    if len(raw) == 6:
        address = raw
    else:
        text = raw.decode('ascii').strip()
        assert re.fullmatch(r'[0-9A-Fa-f]{12}|(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}', text)
        address = bytes.fromhex(text.replace(':', ''))
    assert len(address) == 6 and not address[0]&1
    assert address not in (bytes(6), b'\xff'*6)
    log('BT_STOCK_ADDRESS_READ_ONLY_VALIDATED')
    return address


def prepare_nvm(data, address, baud=115200):
    """Select the complete Bluetooth TLV from the stock Bluetooth/FM container."""
    checked_tlv(data, 4)
    offset = 4
    bt = None
    while offset < len(data):
        assert offset+4 <= len(data)
        header = struct.unpack_from('<I', data, offset)[0]
        end = offset+4+(header >> 8)
        assert end <= len(data)
        if header & 255 == 2:
            assert bt is None, 'Duplicate Bluetooth NVM'
            bt = bytearray(data[offset:end])
        else:
            assert header & 255 == 3, 'Unexpected NVM subtype'
        offset = end
    assert offset == len(data) and bt is not None
    checked_tlv(bt, 2)
    offset = 4
    changed = set()
    while offset < len(bt):
        assert offset+12 <= len(bt)
        tag, size, _, _ = struct.unpack_from('<HHII', bt, offset)
        start = offset+12
        end = start+size
        assert end <= len(bt)
        if tag in (2, 17, 27):
            assert tag not in changed, 'Duplicate transport/address NVM tag'
            changed.add(tag)
        if tag == 2:
            assert size == 6
            bt[start:end] = address[::-1]
        elif tag == 17:
            assert size == 9
            bt[start] &= ~0x80  # H4 has no Qualcomm IBS byte handling.
            bt[start+2] = {115200: 0, 3000000: 0x0e}[baud]
        elif tag == 27:
            assert size == 1
            bt[start] &= ~1  # No controller deep sleep with IBS disabled.
        offset = end
    assert offset == len(bt) and changed == {2, 17, 27}
    return bytes(bt)


class UART:
    def __init__(self):
        device = Path('/dev/ttyHS0')
        assert stat.S_ISCHR(device.stat().st_mode)
        assert '4a8c000' in str(Path('/sys/class/tty/ttyHS0/device').resolve())
        self.device = device
        self.fd = None
        self.original = None
        self.clock_voted = False
        self.buffer = bytearray()
        self.diagnostic_packets = 0

    def open(self):
        self.fd = os.open(self.device, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
        fcntl.ioctl(self.fd, termios.TIOCEXCL)
        discipline = struct.unpack('i', fcntl.ioctl(self.fd, termios.TIOCGETD, struct.pack('i', 0)))[0]
        assert discipline == 0, 'UART already attached'
        if self.original is None:
            self.original = termios.tcgetattr(self.fd)
        assert fcntl.ioctl(self.fd, 0x544d) == 0, 'UART clock vote failed'
        self.clock_voted = True

    def close(self, restore=False):
        if self.fd is not None:
            if restore and self.original is not None:
                termios.tcsetattr(self.fd, termios.TCSANOW, self.original)
            if self.clock_voted:
                fcntl.ioctl(self.fd, 0x544e)
                self.clock_voted = False
            os.close(self.fd)
            self.fd = None

    def configure(self, baud, flow):
        settings = termios.tcgetattr(self.fd)
        settings[0] = settings[1] = settings[3] = 0
        settings[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
        if flow:
            settings[2] |= termios.CRTSCTS
        settings[4] = settings[5] = baud
        settings[6][termios.VMIN] = settings[6][termios.VTIME] = 0
        termios.tcsetattr(self.fd, termios.TCSANOW, settings)
        self.flow(flow)

    def flow(self, enabled):
        modem = struct.unpack('I', fcntl.ioctl(self.fd, termios.TIOCMGET, struct.pack('I', 0)))[0]
        flags = termios.TIOCM_RTS | getattr(termios, 'TIOCM_OUT2', 0x4000)
        modem = modem | flags if enabled else modem & ~flags
        fcntl.ioctl(self.fd, termios.TIOCMSET, struct.pack('I', modem))

    def write(self, data):
        pending = memoryview(data)
        deadline = time.monotonic()+3
        while pending:
            assert time.monotonic() < deadline, 'UART transmit timed out'
            if not select.select([], [self.fd], [], 0.1)[1]:
                continue
            try:
                count = os.write(self.fd, pending)
            except BlockingIOError:
                continue
            assert count > 0
            pending = pending[count:]

    def command(self, opcode, payload=b''):
        assert len(payload) <= 255
        self.write(b'\x01'+struct.pack('<HB', opcode, len(payload))+payload)

    def event(self, deadline):
        while time.monotonic() < deadline:
            if self.buffer:
                if self.buffer[0] == 2:
                    # The stock patch emits diagnostic ACL records at handle
                    # 0x0edc until its logging-disable command takes effect.
                    # No real connections exist during this bootstrap.
                    if len(self.buffer) >= 5:
                        handle, length = struct.unpack_from('<HH', self.buffer, 1)
                        assert handle & 0xfff == 0xedc and length <= 2048, 'Unexpected bootstrap ACL packet'
                        if len(self.buffer) >= length+5:
                            del self.buffer[:length+5]
                            self.diagnostic_packets += 1
                            assert self.diagnostic_packets <= 64
                            continue
                    if select.select([self.fd], [], [], 0.1)[0]:
                        self.buffer.extend(os.read(self.fd, 1024))
                    continue
                assert self.buffer[0] == 4, 'Unexpected H4/IBS byte: '+self.buffer[:32].hex()
                if len(self.buffer) >= 3:
                    end = 3+self.buffer[2]
                    if len(self.buffer) >= end:
                        event = self.buffer[1]
                        payload = bytes(self.buffer[3:end])
                        del self.buffer[:end]
                        return event, payload
            if select.select([self.fd], [], [], 0.1)[0]:
                try:
                    self.buffer.extend(os.read(self.fd, 1024))
                except BlockingIOError:
                    pass
                assert len(self.buffer) <= 4096, 'Unexpected UART stream'
        raise TimeoutError('HCI event timed out; buffered='+self.buffer[:32].hex())

    def vendor(self, rtype, timeout=3):
        deadline = time.monotonic()+timeout
        while True:
            event, payload = self.event(deadline)
            if event == 0xff:
                assert len(payload) >= 2 and payload[:2] == bytes([0, rtype]), 'Unexpected vendor response '+payload.hex()
                return payload[2:]
            assert event == 0x0e and len(payload) >= 4 and payload[3] == 0, 'Unexpected HCI response '+payload.hex()

    def complete(self, opcode, timeout=3):
        deadline = time.monotonic()+timeout
        while True:
            event, payload = self.event(deadline)
            assert event == 0x0e and len(payload) >= 4, 'Unexpected command response '+payload.hex()
            returned = struct.unpack_from('<H', payload, 1)[0]
            assert payload[3] == 0, 'HCI command failed '+payload.hex()
            if returned == opcode:
                return payload[4:]
            assert returned == 0, 'Unrelated HCI completion'

    def version(self, patched=False):
        self.command(0xfc00, b'\x19')
        raw = self.vendor(2)
        assert len(raw) == 12, 'Invalid version reply'
        product, patch, rom, soc = struct.unpack('<IHHI', raw)
        log(f'BT_VERSION_REPLY product=0x{product:08x} patch=0x{patch:04x} rom=0x{rom:04x} soc=0x{soc:08x}')
        expected = (0x0a, 0x0201, 0x40020140) if patched else EXPECTED_VERSION
        assert (product, rom, soc) == expected, 'Unrecognized Bluetooth controller'
        assert patch == (2 if patched else 1), 'Unexpected controller patch version'
        self.complete(0)
        return patch

    def power_on(self):
        self.open()
        self.configure(termios.B2400, False)
        self.write(b'\xc0')
        time.sleep(0.1)
        self.configure(termios.B115200, False)
        self.write(b'\xfc')
        time.sleep(0.15)
        self.close()
        self.open()
        self.configure(termios.B115200, True)
        termios.tcflush(self.fd, termios.TCIFLUSH)
        self.version()

    def fast_baud(self):
        # The stock HAL only lowers RTS here; CTS remains enabled. Changing
        # termios before the baud command also reprograms the GENI engine.
        self.flow(False)
        self.command(0xfc48, b'\x0e')
        time.sleep(0.02)
        termios.tcdrain(self.fd)
        self.configure(termios.B3000000, True)
        # Some WCN variants emit no baud acknowledgement. A fresh guarded
        # version request proves communication at the new speed instead.
        deadline = time.monotonic()+0.2
        while time.monotonic() < deadline:
            if select.select([self.fd], [], [], 0.02)[0]:
                data = os.read(self.fd, 1024)
                if data:
                    log('BT_BAUD_REPLY='+data.hex())
        self.buffer.clear()
        self.version()
        log('BT_UART_3000000_VERIFIED')

    def download(self, data, skip, label):
        start = time.monotonic()
        chunks = (len(data)+242)//243
        for index, offset in enumerate(range(0, len(data), 243)):
            segment = data[offset:offset+243]
            self.command(0xfc00, bytes([0x1e, len(segment)])+segment)
            if index == chunks-1:
                pending = struct.unpack('i', fcntl.ioctl(self.fd, termios.TIOCOUTQ, struct.pack('i', 0)))[0]
                log(f'BT_DOWNLOAD {label} final_segment_queued elapsed={time.monotonic()-start:.2f}s tty_pending={pending}')
            if not skip or index == chunks-1:
                result = self.vendor(4, timeout=10)
                assert result == b'\x00', 'Firmware download rejected: '+result.hex()
            if index and index % 200 == 0:
                log(f'BT_DOWNLOAD {label} segments={index}/{chunks}')
            assert time.monotonic()-start < 30, 'Firmware transfer deadline exceeded'
        log(f'BT_DOWNLOAD {label} bytes={len(data)} segments={chunks} elapsed={time.monotonic()-start:.2f}s')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--probe', action='store_true', help='Only verify the controller at 3 Mbaud')
    parser.add_argument('--initialize', action='store_true', help='Initialize without installing a kernel line discipline')
    parser.add_argument('--baud', type=int, choices=[115200, 3000000], default=3000000)
    args = parser.parse_args()
    assert not (args.probe and args.initialize)
    radios = [p for p in Path('/sys/class/rfkill').glob('rfkill*') if (p/'name').read_text().strip() == 'bt_power']
    assert len(radios) == 1
    radio = radios[0]/'soft'
    original_block = radio.read_text().strip()
    uart = UART()
    assert not list(Path('/sys/class/bluetooth').glob('hci*')), 'Bluetooth controller already attached'
    child = None
    keep_power = False

    def interrupted(signum, frame):
        raise InterruptedError(f'Signal {signum}')
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    def timed_out(signum, frame):
        raise TimeoutError('Bluetooth bootstrap exceeded 35 seconds')
    signal.signal(signal.SIGALRM, timed_out)
    signal.alarm(35)

    try:
        radio.write_text('0\n')
        time.sleep(0.2)
        uart.power_on()
        if args.baud == 3000000:
            uart.fast_baud()
        if args.probe:
            return
        root = Path('/lib/firmware/postmarketos')
        patch = (root/'apbtfw11.tlv').read_bytes()
        nvm = (root/'apnv11.bin').read_bytes()
        assert hashlib.sha256(patch).hexdigest() == PATCH_SHA
        assert hashlib.sha256(nvm).hexdigest() == NVM_SHA
        body = checked_tlv(patch, 1)
        assert body[10] == 3, 'Unexpected patch download mode'
        product, rom, version = struct.unpack_from('<HHH', body, 12)
        assert (product, rom, version) == (0x0a, 0x0201, 2)
        address = stock_address()
        nvm = prepare_nvm(nvm, address, args.baud)
        uart.download(patch, True, 'patch')
        time.sleep(0.02)
        uart.download(nvm, False, 'bluetooth-nvm')
        uart.command(0x0c03)
        uart.complete(0x0c03)
        uart.command(0xfc17, b'\x14\x00')
        uart.complete(0xfc17)
        log('BT_CONTROLLER_DIAGNOSTIC_LOGGING_DISABLED')
        assert uart.version(patched=True) == 2, 'Firmware patch version mismatch'
        uart.command(0x1009)
        returned = uart.complete(0x1009)
        assert returned == address[::-1], 'Controller address does not match stock calibration'
        log('BT_STOCK_FIRMWARE_AND_ADDRESS_VERIFIED')
        signal.alarm(0)
        if args.initialize:
            uart.close()
            keep_power = True
            return
        # Keep this fd and its downstream clock vote for the H4 lifetime.
        # Clearing only exclusive-open lets btattach open the same UART.
        # IBS/deep sleep remain disabled until a kernel transport supports them.
        fcntl.ioctl(uart.fd, termios.TIOCNXCL)
        child = subprocess.Popen(['/usr/sbin/btattach', '-B', '/dev/ttyHS0', '-S', str(args.baud), '-P', 'h4'])
        log('BT_H4_TRANSPORT_STARTED')
        controller = Path('/sys/class/bluetooth/hci0')
        deadline = time.monotonic()+6
        while time.monotonic() < deadline:
            assert child.poll() is None, 'btattach stopped before HCI registration'
            if controller.exists():
                break
            time.sleep(0.1)
        else:
            raise TimeoutError('Patched HCI controller did not register')
        hc_radios = [p for p in Path('/sys/class/rfkill').glob('rfkill*') if (p/'name').read_text().strip() == 'hci0']
        assert len(hc_radios) == 1 and (hc_radios[0]/'type').read_text().strip() == 'bluetooth'
        (hc_radios[0]/'soft').write_text('0\n')
        log('BT_HCI_CONTROLLER_READY')
        status = child.wait()
        assert status == 0, f'btattach exited {status}'
    finally:
        signal.alarm(0)
        if child is not None and child.poll() is None:
            child.terminate()
            try:
                child.wait(timeout=3)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait(timeout=2)
        uart.close(restore=not keep_power)
        if not keep_power:
            blocked = original_block if args.probe else '1'
            radio.write_text(blocked+'\n')
            log('BT_RFKILL_STATE_RESTORED='+blocked)


if __name__ == '__main__':
    main()
