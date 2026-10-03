; =============================================================================
; AURA-OS v2 — kernel/gdt_idt.asm
; 64-bit GDT (0x08 code / 0x10 data) + full IDT.
; Exceptions print vector+cr2 to serial then halt. IRQs dispatch via table.
; =============================================================================
%macro PUSHALL 0
    push rax
    push rcx
    push rdx
    push rbx
    push rbp
    push rsi
    push rdi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
%endmacro

%macro POPALL 0
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rbp
    pop rbx
    pop rdx
    pop rcx
    pop rax
%endmacro

gdt_install:
    xor eax, eax
    mov [gdt_k], rax
    mov rax, 0x00AF9A000000FFFF
    mov [gdt_k + 8], rax            ; 0x08 64-bit code
    mov rax, 0x00CF92000000FFFF
    mov [gdt_k + 16], rax           ; 0x10 data
    mov word [gdt_k_desc], 23
    mov rax, gdt_k
    mov [gdt_k_desc + 2], rax
    lgdt [gdt_k_desc]
    push qword 0x08
    lea rax, [.reload]
    push rax
    retfq
.reload:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax
    ret

; ---------------- exception stubs ----------------
%assign v 0
%rep 32
exc%+v:
%if v == 14
    mov rdi, v
    mov rsi, cr2
%else
    mov rdi, v
    xor rsi, rsi
%endif
    jmp exc_common
%assign v v+1
%endrep

exc_common:
    cli
    mov [exc_vec], rdi
    mov [exc_cr2], rsi
    PUSHALL
    lea rsi, [msg_fault]
    call ser_puts
    mov rdi, [exc_vec]
    call ser_put_dec
    lea rsi, [msg_cr2]
    call ser_puts
    mov rdi, [exc_cr2]
    call ser_put_hex
    lea rsi, [msg_crlf]
    call ser_puts
.h:
    hlt
    jmp .h

msg_fault db "AURA-FAULT vec=", 0
msg_cr2   db " cr2=0x", 0
msg_crlf  db 10, 0

exc_vec  dq 0
exc_cr2  dq 0

; ---------------- IRQ stubs ----------------
%assign v 0
%rep 16
irq%+v:
    PUSHALL
    mov rdi, v
    call irq_dispatch
    POPALL
    iretq
%assign v v+1
%endrep

; unused vectors (48..255)
vec_iret:
    iretq

; rdi = irq number (0..15)
irq_dispatch:
    PUSHALL
    cmp rdi, 0
    jne .n0
    inc dword [pit_ticks]
    jmp .eoi
.n0:
    cmp rdi, 1
    jne .n1
    call kbd_irq
    jmp .eoi
.n1:
    cmp rdi, 12
    jne .eoi
    call mouse_irq
.eoi:
    mov al, 0x20
    out 0xA0, al                ; EOI slave (harmless if unused)
    out 0x20, al                ; EOI master
    POPALL
    ret

; ---------------- IDT (assembly-time built, 16 bytes per entry) ----------------
; (label - $$) is a plain scalar offset; add KBASE (== org) to reconstruct
; the absolute linear address, then split into IDT-gate fields.
KBASE equ 0x100000
%macro IDTE 1
    dw (((%1) - $$) + KBASE) & 0xFFFF
    dw 0x08
    db 0
    db 0x8E
    dw ((((%1) - $$) + KBASE) >> 16) & 0xFFFF
    dd ((((%1) - $$) + KBASE) >> 32) & 0xFFFFFFFF
    dd 0
%endmacro

align 16
idt_k:
%assign v 0
%rep 32
    IDTE exc %+ v
%assign v v+1
%endrep
%assign v 0
%rep 16
    IDTE irq %+ v
%assign v v+1
%endrep
%assign v 48
%rep 208
    IDTE vec_iret
%assign v v+1
%endrep

idt_k_desc:
    dw 256*16 - 1
    dq idt_k

idt_install:
    lidt [idt_k_desc]
    ret
