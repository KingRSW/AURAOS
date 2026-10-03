; =============================================================================
; AURA-OS v2 — kernel/pic_pit.asm
; PIC remap (master 0x20..0x27, slave 0x28..0x2F) + PIT channel 0 @ 100 Hz.
; =============================================================================
IO_DELAY_CNT equ 0

io_wait:
    jmp $+2
    ret

pic_init:
    mov al, 0x11
    out 0x20, al
    call io_wait
    out 0xA0, al
    call io_wait
    mov al, 0x20              ; master offset 0x20
    out 0x21, al
    call io_wait
    mov al, 0x28              ; slave offset 0x28
    out 0xA1, al
    call io_wait
    mov al, 0x04              ; slave on IR2
    out 0x21, al
    call io_wait
    mov al, 0x02
    out 0xA1, al
    call io_wait
    mov al, 0x01              ; 8086 mode
    out 0x21, al
    call io_wait
    out 0xA1, al
    call io_wait
    xor al, al                ; unmask all
    out 0x21, al
    out 0xA1, al
    ret

pit_init:
    mov al, 0x36              ; ch0, lo/hi, mode 3
    out 0x43, al
    mov al, 11932 & 0xFF      ; 1193182 / 11932 ~= 100 Hz
    out 0x40, al
    mov al, 11932 >> 8
    out 0x40, al
    ret
