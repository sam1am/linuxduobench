"""Rewrite the RAM image's ramdisk: replace /init, drop named files, add root/.ssh/authorized_keys. Everything else
is copied entry by entry. usage: repack.py <in.img> <new init> <key.pub> <out.img> [drop ...]"""
import gzip, hashlib, struct, sys
src, initf, pub, out = sys.argv[1:5]; drop = set(sys.argv[5:])
b = open(src, 'rb').read()
assert b[:8] == b'ANDROID!' and struct.unpack_from('<I', b, 40)[0] == 2
ks, = struct.unpack_from('<I', b, 8); rs, = struct.unpack_from('<I', b, 16); page, = struct.unpack_from('<I', b, 36)
ds, = struct.unpack_from('<I', b, 1648); up = lambda n: -(-n // page) * page
K = b[page:page + ks]; ro = page + up(ks); R = b[ro:ro + rs]; do = ro + up(rs); D = b[do:do + ds]
c = gzip.decompress(R)
def entry(name, mode, data=b'', ino=0):
    nb = name.encode() + b'\0'
    f = [ino, mode, 0, 0, 1, 0, len(data), 0, 0, 0, 0, len(nb), 0]
    h = b'070701' + ''.join('%08x' % x for x in f).encode()
    return h + nb + b'\0' * (-(len(h) + len(nb)) % 4) + data + b'\0' * (-len(data) % 4)
new = bytearray(); o = 0; seen = []; newinit = open(initf, 'rb').read().replace(b'\r', b'')
while True:
    assert c[o:o+6] == b'070701', o
    f = [int(c[o+6+8*i:o+14+8*i], 16) for i in range(13)]
    name = c[o+110:o+110+f[11]-1].decode(); ds_ = o + 110 + f[11]; ds_ += -ds_ % 4
    end = ds_ + f[6]; end += -end % 4
    if name == 'TRAILER!!!': break
    n = name[2:] if name.startswith('./') else name
    if n in drop: seen.append('dropped ' + n)
    elif n == 'init':
        assert f[4] == 1; seen.append('replaced init'); new += entry(name, f[1], newinit, f[0])
    elif n.startswith('root/.ssh/authorized_keys'): seen.append('dropped old key')
    else: new += c[o:end]
    o = end
key = open(pub, 'rb').read().strip(); assert key.startswith(b'ssh-')
new += entry('root/.ssh/authorized_keys', 0o100600, key + b'\n', 0xfffff0) + entry('TRAILER!!!', 0)
print(seen); assert 'replaced init' in seen and all(('dropped ' + d) in seen for d in drop)
R2 = gzip.compress(bytes(new), 9, mtime=0)
sha = hashlib.sha1()
for blob in (K, R2, b'', b'', D): sha.update(blob); sha.update(struct.pack('<I', len(blob)))
hdr = bytearray(b[:page]); struct.pack_into('<I', hdr, 16, len(R2)); hdr[576:608] = sha.digest().ljust(32, b'\0')
pad = lambda x: x + b'\0' * (up(len(x)) - len(x))
open(out, 'wb').write(bytes(hdr) + pad(K) + pad(R2) + pad(D))
print('wrote', out, 'ramdisk', rs, '->', len(R2))
