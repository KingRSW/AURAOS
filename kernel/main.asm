; =============================================================================
; AURA-OS v2 — kernel/main.asm
; Single translation unit: this file + %include of all kernel modules.
; Flat binary, org 0x100000. 16-byte header: 'AKRN', size32 (patched at
; build time by scripts/patch_size.py), 8 bytes reserved. Entry at +0x10.
; stage2 jumps here in long mode with rdi = 0x5000 (BOOTINFO).
; =============================================================================
BITS 64
org 0x100000

; ---- window struct layout (shared gui/apps) ----
%define W_X      0
%define W_Y      4
%define W_W      8
%define W_H      12
%define W_Z      16
%define W_APP    20
%define W_VIS    24
%define W_FOC    28
%define W_TITLE  32
; struct size 48, 8 slots (kernel/bss.inc)

; ---- header ----
dd 0x4E524B41                 ; 'AKRN'
dd 0                          ; kernel size (build-time patch)
dq 0

; =============================================================================
; entry: long mode, paging on, rdi = BOOTINFO
; =============================================================================
kentry:
    cli
    cld
    ; zero .bss
    mov rdi, bss_start
    mov rcx, bss_end
    sub rcx, rdi
    xor eax, eax
    rep stosb
    ; stack above bss
    mov rax, bss_end
    add rax, 0x10000
    and rax, ~15
    mov rsp, rax
    xor ebp, ebp
    mov rdi, 0x5000
    call kmain
.h:
    hlt
    jmp .h

; =============================================================================
kmain:
    push rbx
    push r12
    push r13
    push r14
    push r15
    call ser_init
    lea rsi, [msg_boot]
    call ser_puts
    call gdt_install
    call idt_install
    call pic_init
    call pit_init
    call kbd_init
    call mouse_init
    sti
    call mem_init
    lea rsi, [msg_mem]
    call ser_puts
    mov rdi, [pmm_free_pages]
    shr rdi, 8
    call ser_put_dec
    lea rsi, [msg_mb]
    call ser_puts
    call gfx_init
    lea rsi, [msg_fb]
    call ser_puts
    mov rdi, [fb_width]
    call ser_put_dec
    lea rsi, [msg_x]
    call ser_puts
    mov rdi, [fb_height]
    call ser_put_dec
    lea rsi, [msg_bpp]
    call ser_puts
    mov edi, [fb_bpp]
    call ser_put_dec
    lea rsi, [msg_nl]
    call ser_puts
    call sin_build
    call aurora_render
    call rtc_read
    call gui_init
    mov byte [dirty], 1
    lea rsi, [msg_ready]
    call ser_puts
    call gui_loop
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

msg_boot  db "[aura] AURA-OS booting", 10, 0
msg_mem   db "[aura] mem free MB: ", 0
msg_mb    db 10, 0
msg_fb    db "[aura] fb ", 0
msg_x     db "x", 0
msg_bpp    db " bpp ", 0
msg_nl    db 10, 0
msg_aur   db "[aura] aurora rendered", 10, 0
msg_ready db "[aura] ready", 10, 0

; =============================================================================
%include "kernel/serial.asm"
%include "kernel/gdt_idt.asm"
%include "kernel/pic_pit.asm"
%include "kernel/kbd.asm"
%include "kernel/mouse.asm"
%include "kernel/mem.asm"
%include "kernel/rtc.asm"
%include "kernel/gfx.asm"
%include "kernel/aurora.asm"
%include "kernel/gui.asm"
%include "kernel/apps.asm"
%include "kernel/font.inc"

; ---- all bss at the very end ----
section .bss nobits
bss_start:
%include "kernel/bss.inc"
alignb 16
bss_end:
