# AURA-OS v2 — pure NASM x86-64 kernel, no OS underneath.
# Image layout: LBA0 MBR | LBA1..32 stage2 | LBA64.. kernel

NASM   ?= nasm
PYTHON ?= python3
QEMU   ?= qemu-system-x86_64
BUILD  := build
IMG    := out/auraos.img

.PHONY: all run smoke clean font

all: $(IMG)

$(BUILD) out:
	mkdir -p $@

$(BUILD)/mbr.bin: boot/mbr.asm | $(BUILD)
	$(NASM) -f bin $< -o $@

$(BUILD)/stage2.bin: boot/stage2.asm | $(BUILD)
	$(NASM) -f bin $< -o $@

$(BUILD)/kernel.bin: kernel/main.asm $(wildcard kernel/*.asm kernel/*.inc) | $(BUILD)
	$(NASM) -f bin -I kernel/ $< -o $@
	$(PYTHON) scripts/patch_size.py $@

$(IMG): $(BUILD)/mbr.bin $(BUILD)/stage2.bin $(BUILD)/kernel.bin | out
	truncate -s 2048K $@
	dd if=$(BUILD)/mbr.bin    of=$@ bs=512 seek=0  conv=notrunc
	dd if=$(BUILD)/stage2.bin of=$@ bs=512 seek=1  conv=notrunc
	dd if=$(BUILD)/kernel.bin of=$@ bs=512 seek=64 conv=notrunc

run: $(IMG)
	$(QEMU) -drive format=raw,file=$(IMG) -m 512

smoke: $(IMG)
	tests/smoke.sh $(IMG)

font:
	$(PYTHON) scripts/genfont.py kernel/font.inc

clean:
	rm -rf $(BUILD) out/auraos.img
