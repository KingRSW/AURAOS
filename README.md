# AURA-OS

A tiny x86-64 operating system built from scratch — no Linux, no existing kernel, pure NASM assembly.

## Features

- **Boot chain**: MBR → stage2 (e820 memory map, VBE 1024x768x32 linear framebuffer, A20, long mode) → 64-bit kernel loaded from disk
- **Kernel**: 64-bit GDT/IDT, PIC remapping, PIT timer, PS/2 keyboard + mouse, physical memory manager, RTC
- **Graphics**: off-screen double buffering, rounded-rect/circle primitives, 8x16 bitmap font, procedurally rendered aurora wallpaper
- **GUI**: macOS-style desktop — top menu bar with live clock, bottom dock, draggable windows with traffic-light close buttons, mouse cursor
- **Apps**: Terminal (command interpreter), Editor, About

## Build

Requires `nasm`. `scripts/genfont.py` (Pillow) regenerates the font, but the committed `kernel/font.inc` is used as-is:

```sh
make            # produces out/auraos.img (2 MB raw disk image)
```

## Run / Test

```sh
make run        # boot in QEMU (GUI window)
make smoke      # headless boot, asserts "[aura] ready" on serial + captures screenshot
```

## Layout

```
boot/            MBR + stage2 (16/32/64-bit transition)
kernel/          kernel modules (main.asm includes everything)
scripts/         build helpers (kernel size patch, font generator)
tests/           headless QEMU smoke test
```

## Image layout

| LBA       | Content            |
|-----------|--------------------|
| 0         | MBR boot sector    |
| 1–32      | stage2             |
| 64…       | kernel (flat binary, org 0x100000) |
