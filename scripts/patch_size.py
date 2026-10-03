#!/usr/bin/env python3
"""Patch the AURA-OS kernel header: offset 4 = total file size (LE32)."""
import struct
import sys


def main(path: str) -> None:
    with open(path, "rb") as f:
        data = bytearray(f.read())
    if data[:4] != b"AKRN":
        sys.exit(f"{path}: bad kernel magic {data[:4]!r}")
    data[4:8] = struct.pack("<I", len(data))
    with open(path, "wb") as f:
        f.write(data)
    print(f"patch_size: {path} = {len(data)} bytes")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: patch_size.py <kernel.bin>")
    main(sys.argv[1])
