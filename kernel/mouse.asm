; =============================================================================
; AURA-OS v2 — kernel/mouse.asm
; PS/2 auxiliary (mouse) port, IRQ12, 3-byte packets -> cursor pos + buttons.
; =============================================================================
mouse_wait_in:                  ; wait until we may WRITE to controller
    push rax
.l:
    in al, 0x64
    test al, 2
    jnz .l
    pop rax
    ret

mouse_wait_out:                 ; wait until output buffer has data
    push rax
.l:
    in al, 0x64
    test al, 1
    jz .l
    pop rax
    ret

; AL = command byte for the mouse
mouse_cmd:
    push rax
    call mouse_wait_in
    mov al, 0xD4
    out 0x64, al
    pop rax
    call mouse_wait_in
    out 0x60, al
    call mouse_wait_out
    in al, 0x60                 ; ACK 0xFA
    ret

mouse_init:
    call mouse_wait_in
    mov al, 0xA8                ; enable auxiliary device
    out 0x64, al
    ; controller config: enable IRQ12 + mouse clock
    call mouse_wait_in
    mov al, 0x20
    out 0x64, al
    call mouse_wait_out
    in al, 0x60
    mov bl, al
    or bl, 0x03                 ; bit1 IRQ12, bit0 kbd clock
    and bl, 0xDF                ; clear bit5 (mouse clock disable)
    push rbx
    call mouse_wait_in
    mov al, 0x60
    out 0x64, al
    pop rbx
    call mouse_wait_in
    mov al, bl
    out 0x60, al
    mov al, 0xF6                ; set defaults
    call mouse_cmd
    mov al, 0xF4                ; enable data reporting
    call mouse_cmd
    mov byte [mouse_cycle], 0
    ret

; called from IRQ12
mouse_irq:
    push rax
    push rcx
    in al, 0x60
    mov cl, al
    cmp byte [mouse_cycle], 0
    je .b0
    cmp byte [mouse_cycle], 1
    je .b1
    ; ---- third byte: apply packet ----
    mov [mouse_raw + 2], cl
    mov byte [mouse_cycle], 0
    cmp dword [fb_width], 0     ; graphics not up yet?
    je .done
    movsx rax, byte [mouse_raw + 1]
    test byte [mouse_raw], 0x10
    jz .nx
    sub rax, 256
.nx:
    add [mouse_x], eax
    movsx rax, byte [mouse_raw + 2]
    test byte [mouse_raw], 0x20
    jz .ny
    sub rax, 256
.ny:
    sub [mouse_y], eax          ; PS/2 +y is up, screen y is down
    ; clamp x
    mov eax, [mouse_x]
    test eax, eax
    jns .cx0
    xor eax, eax
.cx0:
    cmp eax, [fb_width]
    jb .cx1
    mov eax, [fb_width]
    dec eax
.cx1:
    mov [mouse_x], eax
    ; clamp y
    mov eax, [mouse_y]
    test eax, eax
    jns .cy0
    xor eax, eax
.cy0:
    cmp eax, [fb_height]
    jb .cy1
    mov eax, [fb_height]
    dec eax
.cy1:
    mov [mouse_y], eax
    mov al, [mouse_raw]
    and al, 7
    mov [mouse_b], al
    mov byte [dirty], 1
    jmp .done
.b0:
    test cl, 0x08               ; sync bit must be set
    jz .done
    mov [mouse_raw], cl
    mov byte [mouse_cycle], 1
    jmp .done
.b1:
    mov [mouse_raw + 1], cl
    mov byte [mouse_cycle], 2
.done:
    pop rcx
    pop rax
    ret
