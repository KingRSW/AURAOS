; =============================================================================
; AURA-OS v2 — kernel/rtc.asm
; CMOS RTC clock (ports 0x70/0x71). Values stored BCD (nibble = digit).
; =============================================================================
rtc_read:
    push rax
.l:
    mov al, 0x0A
    out 0x70, al
    in al, 0x71
    test al, 0x80               ; update-in-progress
    jnz .l
    mov al, 0
    out 0x70, al
    in al, 0x71
    mov [rtc_s], al
    mov al, 2
    out 0x70, al
    in al, 0x71
    mov [rtc_m], al
    mov al, 4
    out 0x70, al
    in al, 0x71
    mov [rtc_h], al
    pop rax
    ret
