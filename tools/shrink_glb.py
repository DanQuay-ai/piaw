#!/usr/bin/env python3
"""Downscale textures embedded in GLB files (web/mobile size). Usage: shrink_glb.py SIZE files..."""
import json, struct, sys, io
from PIL import Image
size = int(sys.argv[1])
for path in sys.argv[2:]:
    d = open(path, 'rb').read()
    jl = struct.unpack_from('<I', d, 12)[0]
    js = json.loads(d[20:20 + jl])
    bo = 20 + jl
    bl = struct.unpack_from('<I', d, bo)[0]
    bin_ = d[bo + 8: bo + 8 + bl]
    img_views = {im['bufferView']: im for im in js.get('images', []) if 'bufferView' in im}
    out = bytearray()
    for i, bv in enumerate(js['bufferViews']):
        data = bin_[bv.get('byteOffset', 0): bv.get('byteOffset', 0) + bv['byteLength']]
        if i in img_views:
            im = Image.open(io.BytesIO(data))
            if max(im.size) > size:
                im.thumbnail((size, size), Image.LANCZOS)
                b = io.BytesIO()
                if im.mode in ('RGBA', 'LA'): im.save(b, 'PNG', optimize=True); img_views[i]['mimeType'] = 'image/png'
                else: im.convert('RGB').save(b, 'JPEG', quality=85); img_views[i]['mimeType'] = 'image/jpeg'
                data = b.getvalue()
        while len(out) % 4: out.append(0)
        bv['byteOffset'] = len(out); bv['byteLength'] = len(data); out += data
    while len(out) % 4: out.append(0)
    js['buffers'][0]['byteLength'] = len(out)
    jb = json.dumps(js, separators=(',', ':')).encode()
    while len(jb) % 4: jb += b' '
    total = 12 + 8 + len(jb) + 8 + len(out)
    open(path, 'wb').write(struct.pack('<III', 0x46546C67, 2, total) + struct.pack('<II', len(jb), 0x4E4F534A) + jb + struct.pack('<II', len(out), 0x004E4942) + out)
    print(path, total // 1024, 'KB')
