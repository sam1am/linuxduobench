"""Read-only dump of phone block devices over the USB serial shell: fixed-size chunks, each checked against the
phone's SHA-256 and retried on mismatch; then the whole device's SHA-256 is compared.
usage: dump2.py <outdir> <chunkMiB> <name>:<device>[:<skipMiB>:<countMiB>] ..."""
import base64, binascii, hashlib, os, select, sys, termios, time
fd = os.open('/dev/cu.usbmodemduo_linux1', os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
a = termios.tcgetattr(fd); a[0] = 0; a[1] = 0; a[3] = 0; a[2] |= termios.CLOCAL | termios.CREAD
termios.tcsetattr(fd, termios.TCSANOW, a)
def rd(t):
    if select.select([fd], [], [], t)[0]:
        try: return os.read(fd, 1 << 20)
        except BlockingIOError: return b''
    return b''
def quiet():
    os.write(fd, b'\x03\n'); q = time.time()
    while time.time() - q < 0.6:
        if rd(0.2): q = time.time()
seq = 0
def run(cmd, timeout=120):
    """run cmd on the phone, return its output bytes (CR stripped) or None"""
    global seq; seq += 1; b, e = b'__B%d__' % seq, b'__E%d__' % seq
    os.write(fd, ('echo __"B%d"__; %s; echo __"E%d"__\n' % (seq, cmd, seq)).encode())
    buf = bytearray(); t = time.time()
    while time.time() - t < timeout:
        d = rd(0.5)
        if d:
            buf += d; t = time.time()
            if e in buf[-4096:]: break
    else: return None
    buf = bytes(buf).replace(b'\r', b''); i = buf.find(b + b'\n'); j = buf.rfind(e)
    return buf[i + len(b) + 1:j] if 0 <= i < j else None
outdir, CH = sys.argv[1], int(sys.argv[2]); allok = True; quiet()
for spec in sys.argv[3:]:
    p = spec.split(':'); name, dev = p[0], p[1]
    size = int(run('cat /sys/class/block/%s/size' % dev.split('/')[-1]).split()[0]) * 512
    skip, total = (int(p[2]) << 20, int(p[3]) << 20) if len(p) > 2 else (0, size)
    if skip < 0: skip = size + skip
    path = os.path.join(outdir, name + '.img'); h = hashlib.sha256(); t0 = time.time(); retries = 0
    done = 0
    with open(path, 'wb') as f:
        while done < total:
            n = min(CH << 20, total - done)
            dd = 'dd if=%s bs=4096 skip=%d count=%d 2>/dev/null' % (dev, (skip + done) // 4096, n // 4096)
            for attempt in range(8):
                out = run('%s | base64; echo ==SUM==; %s | sha256sum' % (dd, dd))
                try:
                    b64, s = out.split(b'==SUM==\n'); raw = base64.b64decode(b64.replace(b'\n', b''), validate=True)
                    if len(raw) == n and hashlib.sha256(raw).hexdigest().encode() == s.split()[0]: break
                except (AttributeError, ValueError, IndexError, binascii.Error): pass
                retries += 1; quiet()
            else: print(name, 'FAILED at offset', done); sys.exit(1)
            f.write(raw); h.update(raw); done += n
            if (done // n) % 64 == 0: print('  %s %d/%d MiB, %d retries, %.1f MB/s' % (name, done >> 20, total >> 20, retries, done / 1048576 / (time.time() - t0)), flush=True)
    whole = run('dd if=%s bs=4096 skip=%d count=%d 2>/dev/null | sha256sum' % (dev, skip // 4096, total // 4096), 900)
    good = whole is not None and whole.split()[0].decode() == h.hexdigest(); allok &= good
    print('%-18s %12d bytes %5.1f MB/s retries %d sha256 %s %s' % (name, total, total / 1048576 / (time.time() - t0), retries, h.hexdigest(), 'VERIFIED' if good else 'MISMATCH'), flush=True)
    with open(os.path.join(outdir, 'SHA256SUMS'), 'a') as sf: sf.write('%s  %s.img\n' % (h.hexdigest(), name) if good else '# MISMATCH %s\n' % name)
sys.exit(0 if allok else 1)
