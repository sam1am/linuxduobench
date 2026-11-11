import os, sys, termios, time, select
fd = os.open('/dev/cu.usbmodemduo_linux1', os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
a = termios.tcgetattr(fd); a[0] = 0; a[1] = 0; a[3] = 0; a[2] |= termios.CLOCAL | termios.CREAD
termios.tcsetattr(fd, termios.TCSANOW, a)
cmd = sys.argv[1]; wait = float(sys.argv[2]) if len(sys.argv) > 2 else 4
os.write(fd, b'\n'); time.sleep(0.3)
os.write(fd, (cmd + '; echo __END__\n').encode())
buf = b''; t = time.time()
while time.time() - t < wait:
    if select.select([fd], [], [], 0.3)[0]:
        try: buf += os.read(fd, 65536)
        except BlockingIOError: pass
        if buf.count(b'__END__') >= 2: break
sys.stdout.write(buf.decode(errors='replace'))
