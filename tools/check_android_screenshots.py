"""Validate Android screenshots using only the Python standard library."""
import hashlib
import struct
import sys
import zlib
from pathlib import Path


def png_pixels(path: Path) -> bytes:
    data = path.read_bytes()
    assert data.startswith(b'\x89PNG\r\n\x1a\n'), f'{path} is not PNG'
    off = 8
    payload = bytearray()
    width = height = depth = color = None
    while off + 12 <= len(data):
        length = struct.unpack_from('>I', data, off)[0]
        tag = data[off + 4:off + 8]
        chunk = data[off + 8:off + 8 + length]
        if tag == b'IHDR':
            width, height, depth, color = struct.unpack('>IIBB', chunk[:10])
        elif tag == b'IDAT':
            payload.extend(chunk)
        elif tag == b'IEND':
            break
        off += 12 + length
    assert width and height and width >= 300 and height >= 500
    assert depth == 8 and color in (2, 6), (path, depth, color)
    pixels = zlib.decompress(payload)
    assert len(pixels) > 100000, 'screenshot too small'
    return pixels


def main(paths):
    a, b = map(lambda p: png_pixels(Path(p)), paths)
    assert hashlib.sha256(a).digest() != hashlib.sha256(b).digest(), 'tap did not change the rendered game'
    print('ANDROID_SCREENSHOTS_OK: native PNGs differ after PLAY tap')


if __name__ == '__main__':
    main(sys.argv[1:])
