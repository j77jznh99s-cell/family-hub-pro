# Renders a top-down PNG of the baked map from build/parts.json (needs Pillow).
# Usage: python3 tools/render_map_preview.py
import json, math
from PIL import Image, ImageDraw
parts = json.load(open('build/parts.json'))
S = 1.4
X0, X1, Z0, Z1 = -270, 270, -400, 360
W, H = int((X1-X0)*S), int((Z1-Z0)*S)
img = Image.new('RGB', (W, H), (60,150,210))
d = ImageDraw.Draw(img, 'RGBA')
def P(x, z): return ((x-X0)*S, (z-Z0)*S)
def topy(p):
    return p['y'] + (p['sx'] if 'Cylinder' in p['shape'] and abs(p['rx'])<0.1 else p['sy'])/2
for p in sorted(parts, key=topy):
    if p['t'] >= 0.99 or p['n'] in ('Sea','Seabed'): continue
    a = int(255*(1-p['t']))
    col = (int(p['r']*255), int(p['g']*255), int(p['b']*255), a)
    sh = p['shape']
    if 'Ball' in sh or ('Cylinder' in sh and abs(p['rx'])<0.1 and abs(p['rz'])<0.1):
        r = (p['sy'] if 'Cylinder' in sh else p['sx'])/2*S
        cx, cy = P(p['x'], p['z'])
        d.ellipse([cx-r, cy-r, cx+r, cy+r], fill=col)
    else:
        # footprint in XZ using right vector; look = up x right approx
        rx, rz = p['rx'], p['rz']
        n = math.hypot(rx, rz) or 1; rx, rz = rx/n, rz/n
        lx, lz = -rz, rx
        hx, hz = p['sx']/2, p['sz']/2
        if 'Cylinder' in sh:  # horizontal cylinder lying along right vector
            hz = p['sy']/2
        pts = [P(p['x']+rx*sx*hx+lx*sz*hz, p['z']+rz*sx*hx+lz*sz*hz) for sx, sz in ((1,1),(1,-1),(-1,-1),(-1,1))]
        d.polygon(pts, fill=col)
img.save('docs/map-preview.png')
print(W, H)
