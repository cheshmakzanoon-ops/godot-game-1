#!/usr/bin/env python3
"""Unpack the reviewed NEEDLEBEAT: DROP alpha source without external download."""
from pathlib import Path
from io import BytesIO
import base64
import lzma
import tarfile

root = Path(__file__).resolve().parents[2]
archive = Path(__file__).with_name("source.tar.xz.b64")
decoded = lzma.decompress(base64.b64decode(archive.read_text(encoding="ascii")))
with tarfile.open(fileobj=BytesIO(decoded), mode="r:") as tar:
    for info in tar.getmembers():
        name = Path(info.name)
        if not info.isfile() or name.is_absolute() or ".." in name.parts:
            raise ValueError("Unsafe or unexpected archive entry: " + info.name)
        target = root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(tar.extractfile(info).read())
archive.unlink()
Path(__file__).unlink()
(root / ".github/workflows/materialize.yml").unlink()
print("Materialized NEEDLEBEAT: DROP source.")
