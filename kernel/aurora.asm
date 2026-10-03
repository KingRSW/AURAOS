; =============================================================================
; AURA-OS v2 — kernel/aurora.asm
; Static "aurora" wallpaper renderer: dark vertical gradient + 4 sine ribbons,
; rendered ONCE at boot into aurora_buf (re-blitted on every repaint).
; =============================================================================
sin_build:
    push rbx
    finit
    xor ebx, ebx
.l:
    mov [sin_i], ebx
    fild dword [sin_i]
    fldpi
    fadd st0, st0               ; 2*pi
    fmulp st1, st0              ; idx * 2*pi
    fidiv dword [c1024]
    fsin
    fimul dword [c127]
    fistp word [sin_tab + rbx*2]
    inc ebx
    cmp ebx, 1024
    jb .l
    pop rbx
    ret

sin_i  dd 0
c1024  dd 1024
c127   dd 127
div767 dd 767

; ribbon params: idx = ((x*kx + y*ky) >> 8 + ph) & 1023
rb_kx   dd 320, -224, 448, -288
rb_ky   dd 512, 640, -384, 448
rb_ph   dd 0, 300, 700, 150
rb_thr  dd 60, 55, 65, 60
rb_gain dd 900, 1000, 850, 950
; packed RGB (00RRGGBB)
rb_col  dd 0x002D78C8, 0x003CC8BE, 0x007C5CE6, 0x00C850B4

; blend channel %1 with ribbon color channel (shift %2) using alpha in ebp
%macro AURBLEND 2
    mov edx, ecx
    shr edx, %2
    and edx, 0xFF
    sub edx, %1
    imul edx, ebp
    mov r8d, 255
    cdq
    idiv r8d
    add %1, eax
%endmacro

aurora_render:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16                 ; [rsp]=r [rsp+4]=g [rsp+8]=b row base colors
    mov r15, [aurora_buf]
    xor r10d, r10d              ; y
.row:
    ; per-row gradient: top (11,16,38) -> bottom (3,5,12)
    mov eax, r10d
    imul eax, eax, 8
    xor edx, edx
    div dword [div767]
    mov ecx, 11
    sub ecx, eax
    mov [rsp], ecx
    mov eax, r10d
    imul eax, eax, 11
    xor edx, edx
    div dword [div767]
    mov ecx, 16
    sub ecx, eax
    mov [rsp + 4], ecx
    mov eax, r10d
    imul eax, eax, 26
    xor edx, edx
    div dword [div767]
    mov ecx, 38
    sub ecx, eax
    mov [rsp + 8], ecx
    xor r11d, r11d              ; x
.col:
    mov r12d, [rsp]             ; accumulated R
    mov r13d, [rsp + 4]         ; G
    mov r14d, [rsp + 8]         ; B
    xor ebx, ebx                ; ribbon index
.rb:
    movsxd rax, dword [rb_kx + rbx*4]
    imul rax, r11
    movsxd rcx, dword [rb_ky + rbx*4]
    imul rcx, r10
    add rax, rcx
    sar rax, 8
    add eax, [rb_ph + rbx*4]
    and eax, 1023
    movsx rax, word [sin_tab + rax*2]
    movsxd rcx, dword [rb_thr + rbx*4]
    sub eax, ecx                ; strength = v - threshold
    jle .noadd
    movsxd rcx, dword [rb_gain + rbx*4]
    imul eax, ecx
    sar eax, 8
    cmp eax, 255
    jbe .aok
    mov eax, 255
.aok:
    mov ebp, eax                ; alpha
    mov ecx, [rb_col + rbx*4]
    AURBLEND r12d, 16
    AURBLEND r13d, 8
    AURBLEND r14d, 0
.noadd:
    inc rbx
    cmp rbx, 4
    jb .rb
    ; pack XRGB
    mov eax, 0xFF000000
    mov edx, r12d
    shl edx, 16
    or eax, edx
    mov edx, r13d
    shl edx, 8
    or eax, edx
    or eax, r14d
    mov [r15], eax
    add r15, 4
    inc r11d
    cmp r11d, [fb_width]
    jb .col
    inc r10d
    cmp r10d, [fb_height]
    jb .row
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret
