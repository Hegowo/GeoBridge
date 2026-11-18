#!/usr/bin/env python3
"""
Generate GeoBridge.icns from scratch using only Python stdlib + sips + iconutil.
Design: macOS-style squircle with a blue gradient and a white location pin.
"""
import struct, zlib, math, os, subprocess, sys

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT    = os.path.dirname(SCRIPT_DIR)
BASE_PNG     = '/tmp/geobridge_icon_base.png'
ICONSET_DIR  = '/tmp/GeoBridge.iconset'
OUT_ICNS     = os.path.join(REPO_ROOT, 'GeoBridge', 'Resources', 'AppIcon.icns')

# ---------------------------------------------------------------------------
# PNG writer (pure stdlib)
# ---------------------------------------------------------------------------

def _png_chunk(chunk_type: bytes, data: bytes) -> bytes:
    payload = chunk_type + data
    return struct.pack('>I', len(data)) + payload + struct.pack('>I', zlib.crc32(payload) & 0xFFFFFFFF)

def write_rgba_png(path: str, width: int, height: int, pixels: bytearray) -> None:
    """pixels must be width*height*4 bytes in RGBA order, row-major."""
    # Build raw scanline data (filter byte 0 = None, then RGBA bytes)
    raw = bytearray()
    stride = width * 4
    for row in range(height):
        raw.append(0)  # filter type None
        raw += pixels[row * stride : (row + 1) * stride]

    ihdr = _png_chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
    idat = _png_chunk(b'IDAT', zlib.compress(bytes(raw), 6))
    iend = _png_chunk(b'IEND', b'')

    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n' + ihdr + idat + iend)

# ---------------------------------------------------------------------------
# Icon renderer
# ---------------------------------------------------------------------------

def render_icon(size: int) -> bytearray:
    s    = size
    half = s * 0.5
    buf  = bytearray(s * s * 4)

    # Squircle mask parameters
    sq_R = half * 0.88    # squircle radius
    sq_N = 5.0            # exponent (≈ macOS icon shape)
    sq_aa_lo = 1.0
    sq_aa_hi = 1.12

    # Pin geometry
    pin_cx  = half
    pin_cy  = half - s * 0.04          # slightly above centre
    pin_r   = s * 0.22                  # circle radius
    pin_r2  = pin_r * pin_r
    hole_r  = pin_r * 0.42
    hole_r2 = hole_r * hole_r
    tail_bot = pin_cy + pin_r * 2.1    # tip of the teardrop

    for y in range(s):
        dy_sq = y - half
        for x in range(s):
            dx_sq = x - half

            # --- Squircle alpha ---
            sq = (abs(dx_sq) / sq_R) ** sq_N + (abs(dy_sq) / sq_R) ** sq_N
            if sq >= sq_aa_hi:
                # Fully outside — leave transparent (0,0,0,0 already in buffer)
                continue
            if sq <= sq_aa_lo:
                sq_alpha = 255
            else:
                sq_alpha = int((sq_aa_hi - sq) / (sq_aa_hi - sq_aa_lo) * 255)

            # --- Background gradient: deep blue → blue ---
            t = y / s
            bg_r = 0
            bg_g = int(0x68 - t * 28)
            bg_b = int(0xFF - t * 52)

            # --- Pin shape ---
            pdx  = x - pin_cx
            pdy  = y - pin_cy
            pd2  = pdx * pdx + pdy * pdy

            in_circle = pd2 <= pin_r2

            # Teardrop tail: triangle from pin_cy downward to tail_bot
            in_tail = False
            if (not in_circle) and (pin_cy <= y <= tail_bot):
                ft = (y - pin_cy) / (tail_bot - pin_cy)
                hw = pin_r * (1.0 - ft)
                in_tail = (abs(pdx) <= hw)

            in_hole = pd2 <= hole_r2

            is_pin = (in_circle or in_tail) and (not in_hole)

            if is_pin:
                pr, pg, pb = 255, 255, 255
            else:
                pr, pg, pb = bg_r, bg_g, bg_b

            idx = (y * s + x) * 4
            buf[idx]     = pr
            buf[idx + 1] = pg
            buf[idx + 2] = pb
            buf[idx + 3] = sq_alpha

    return buf

# ---------------------------------------------------------------------------
# Build iconset & .icns
# ---------------------------------------------------------------------------

ICONSET_SPEC = [
    ('icon_16x16.png',       16),
    ('icon_16x16@2x.png',    32),
    ('icon_32x32.png',       32),
    ('icon_32x32@2x.png',    64),
    ('icon_128x128.png',     128),
    ('icon_128x128@2x.png',  256),
    ('icon_256x256.png',     256),
    ('icon_256x256@2x.png',  512),
    ('icon_512x512.png',     512),
    ('icon_512x512@2x.png',  1024),
]

def sips_resize(src: str, dest: str, size: int) -> None:
    subprocess.run(
        ['sips', '-z', str(size), str(size), src, '--out', dest],
        check=True, capture_output=True
    )

def main() -> None:
    print('Rendering base icon (512×512)…')
    pixels = render_icon(512)
    write_rgba_png(BASE_PNG, 512, 512, pixels)
    print(f'  → {BASE_PNG}')

    # Need a 1024 version for the @2x 512 slot
    base_1024 = '/tmp/geobridge_icon_1024.png'
    print('Upscaling to 1024×1024…')
    sips_resize(BASE_PNG, base_1024, 1024)

    os.makedirs(ICONSET_DIR, exist_ok=True)
    print('Building iconset…')
    for fname, sz in ICONSET_SPEC:
        src = base_1024 if sz == 1024 else BASE_PNG
        dest = os.path.join(ICONSET_DIR, fname)
        sips_resize(src, dest, sz)
        print(f'  {fname}  ({sz}px)')

    print(f'Running iconutil → {OUT_ICNS}')
    subprocess.run(
        ['iconutil', '-c', 'icns', '-o', OUT_ICNS, ICONSET_DIR],
        check=True
    )
    print('Done.')

if __name__ == '__main__':
    main()
