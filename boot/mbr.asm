; =============================================================================
; AURA-OS v2 — boot/mbr.asm
; 512-byte BIOS boot sector. Loads stage2 (32 sectors @ LBA 1) to 0x7E00
; using INT 13h extended read, then far-jumps to it.
; Assembled flat, must be exactly 512 bytes with 0xAA55 signature.
; =============================================================================
BITS 16
ORG 0x7C00

STAGE2_SECTORS  equ 32              ; stage2 size budget (16 KiB)
STAGE2_LBA      equ 1

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    mov [boot_drive], dl            ; BIOS passes boot drive in DL
    sti

    cld
    mov si, msg_boot
    call bios_print

    ; --- load stage2 via INT 13h AH=42h (extended read) ---
    mov si, dap
    mov byte [dap + 2], STAGE2_SECTORS
    mov word [dap + 4], 0x7E00      ; offset
    mov word [dap + 6], 0           ; segment
    mov dword [dap + 8], STAGE2_LBA
    mov dword [dap + 12], 0
    mov dl, [boot_drive]
    mov ah, 0x42
    int 0x13
    jc  disk_error

    mov si, msg_ok
    call bios_print

    jmp 0x0000:0x7E00               ; hand off to stage2

disk_error:
    mov si, msg_err
    call bios_print
.halt:
    hlt
    jmp .halt

; --- print ASCIZ at SI via BIOS teletype ---
bios_print:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    jmp bios_print
.done:
    ret

msg_boot db "AURA:boot ", 0
msg_ok   db "s2 ", 0
msg_err  db "ERR", 0

boot_drive db 0

; --- Disk Address Packet (must be 16-byte aligned not required, but keep tidy) ---
dap:
    db 0x10, 0                      ; size, reserved
    db 0, 0                         ; sectors, reserved (patched)
    dw 0, 0                         ; buffer offset:seg (patched)
    dq 0                            ; starting LBA (patched)

    times 510-($-$$) db 0
    dw 0xAA55
