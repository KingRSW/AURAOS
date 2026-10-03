; =============================================================================
; AURA-OS v2 — kernel/kbd.asm
; PS/2 keyboard, scancode set 1 -> ASCII ring buffer. Extended (E0) keys ignored.
; =============================================================================
kbd_init:
    mov byte [kbd_head], 0
    mov byte [kbd_tail], 0
    mov byte [kbd_shift], 0
    mov byte [kbd_ext], 0
    ret

; called from IRQ1 (registers already saved by dispatcher)
kbd_irq:
    push rax
    push rcx
    push rdx
    push r8
    in al, 0x60
    cmp al, 0xE0
    je .ext
    cmp byte [kbd_ext], 1
    je .clear_ext
    test al, 0x80
    jnz .break
    ; ---- make code ----
    cmp al, 0x2A
    je .shift_on
    cmp al, 0x36
    je .shift_on
    movzx eax, al
    cmp eax, 128
    jae .done
    lea rdx, [kmap_norm]
    cmp byte [kbd_shift], 0
    je .norm
    lea rdx, [kmap_shift]
.norm:
    mov al, [rdx + rax]
    test al, al
    jz .done
    movzx rcx, byte [kbd_head]
    lea r8, [kbd_buf]
    mov [r8 + rcx], al
    inc cl
    and cl, 127
    mov [kbd_head], cl
    jmp .done
.shift_on:
    mov byte [kbd_shift], 1
    jmp .done
.break:
    and al, 0x7F
    cmp al, 0x2A
    je .shift_off
    cmp al, 0x36
    je .shift_off
    jmp .done
.shift_off:
    mov byte [kbd_shift], 0
    jmp .done
.ext:
    mov byte [kbd_ext], 1
    jmp .done
.clear_ext:
    mov byte [kbd_ext], 0
.done:
    pop r8
    pop rdx
    pop rcx
    pop rax
    ret

; non-blocking: AL = 0 if empty, else ASCII
kbd_getkey:
    push rcx
    movzx ecx, byte [kbd_tail]
    movzx edx, byte [kbd_head]
    cmp cl, dl
    je .empty
    lea rdx, [kbd_buf]
    mov al, [rdx + rcx]
    inc cl
    and cl, 127
    mov [kbd_tail], cl
    pop rcx
    ret
.empty:
    xor eax, eax
    pop rcx
    ret

; ---- scancode set 1 -> ASCII tables (index = make code, 0 = ignore) ----
kmap_norm:
    db 0, 0
    db "1234567890-="              ; 0x02..0x0D
    db 8                            ; 0x0E backspace
    db 9                            ; 0x0F tab
    db "qwertyuiop[]"              ; 0x10..0x1B
    db 10                           ; 0x1C enter
    db 0                            ; 0x1D ctrl
    db "asdfghjkl;'"               ; 0x1E..0x28
    db "`"                          ; 0x29
    db 0                            ; 0x2A lshift
    db "\"                          ; 0x2B backslash
    db "zxcvbnm,./"                ; 0x2C..0x35
    db 0, 0, 0                      ; 0x36..0x38
    db " "                          ; 0x39 space
    times 70 db 0

kmap_shift:
    db 0, 0
    db "!@#$%^&*()_+"
    db 8
    db 9
    db "QWERTYUIOP{}"
    db 10
    db 0
    db 'ASDFGHJKL:', '"'
    db "~"
    db 0
    db "|"
    db "ZXCVBNM<>?"
    db 0, 0, 0
    db " "
    times 70 db 0
