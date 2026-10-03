; =============================================================================
; AURA-OS v2 — kernel/serial.asm
; COM1 (0x3F8) 38400 8N1. Primary debug/assert channel (QEMU headless tests).
; =============================================================================
SER_PORT equ 0x3F8

ser_init:
    push rdx
    push rax
    mov dx, SER_PORT + 1
    xor al, al                 ; disable UART interrupts
    out dx, al
    mov dx, SER_PORT + 3
    mov al, 0x80               ; DLAB on
    out dx, al
    mov dx, SER_PORT
    mov al, 3                  ; divisor 3 -> 38400 baud
    out dx, al
    mov dx, SER_PORT + 1
    xor al, al
    out dx, al
    mov dx, SER_PORT + 3
    mov al, 0x03               ; 8N1, DLAB off
    out dx, al
    mov dx, SER_PORT + 2
    mov al, 0xC7               ; FIFO enable+clear, 14-byte threshold
    out dx, al
    mov dx, SER_PORT + 4
    mov al, 0x0B               ; DTR|RTS|OUT2
    out dx, al
    pop rax
    pop rdx
    ret

; AL = byte to send
ser_putc:
    push rdx
    push rax
    mov dx, SER_PORT + 5
.wait:
    in al, dx
    test al, 0x20              ; THR empty
    jz .wait
    pop rax
    mov dx, SER_PORT
    out dx, al
    pop rdx
    ret

; RSI = ASCIZ string
ser_puts:
    push rsi
    push rax
.l:
    lodsb
    test al, al
    jz .d
    call ser_putc
    jmp .l
.d:
    pop rax
    pop rsi
    ret

; RDI = value (hex, 16 digits)
ser_put_hex:
    push rdi
    push rcx
    push rax
    mov rcx, 16
.l:
    rol rdi, 4
    mov rax, rdi
    and al, 0x0F
    cmp al, 10
    jb .dig
    add al, 'A' - 10
    jmp .p
.dig:
    add al, '0'
.p:
    call ser_putc
    loop .l
    pop rax
    pop rcx
    pop rdi
    ret

; RDI = u32 decimal
ser_put_dec:
    push rdi
    push rsi
    push rax
    sub rsp, 24
    mov rsi, rsp
    call u32_to_str
    mov rsi, rax
    call ser_puts
    add rsp, 24
    pop rax
    pop rsi
    pop rdi
    ret
