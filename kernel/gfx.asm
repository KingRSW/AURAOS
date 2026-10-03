; =============================================================================
; AURA-OS v2 — kernel/gfx.asm
; Framebuffer primitives on an off-screen back buffer + present (blit).
; VBE 1024x768x32 LFB, info from BOOTINFO.
; All routines assume DF=0 (cld done in kernel entry).
; =============================================================================
gfx_init:
    mov rax, [0x5000]
    mov [fb_addr], rax
    mov eax, [0x5008]
    mov [fb_pitch], eax
    mov eax, [0x500C]
    mov [fb_width], eax
    mov eax, [0x5010]
    mov [fb_height], eax
    mov eax, [0x5014]
    mov [fb_bpp], eax
    ; static aurora wallpaper buffer (768 pages = 3 MiB)
    mov rdi, 768
    call pmm_alloc_run
    test rax, rax
    jz .fail
    mov [aurora_buf], rax
    ; working back buffer
    mov rdi, 768
    call pmm_alloc_run
    test rax, rax
    jz .fail
    mov [bb_addr], rax
    ret
.fail:
    lea rsi, [msg_oom]
    call ser_puts
.h: hlt
    jmp .h

msg_oom db "[aura] FATAL: pmm_alloc_run failed", 10, 0

; ---------------------------------------------------------------------------
; edi=x esi=y edx=color  (clipped)
gfx_px:
    cmp edi, 0
    jl .o
    cmp esi, 0
    jl .o
    cmp edi, [fb_width]
    jge .o
    cmp esi, [fb_height]
    jge .o
    mov eax, [fb_pitch]
    imul rax, rsi
    lea rax, [rax + rdi*4]      ; pitch*y (bytes) + x*4
    mov rcx, [bb_addr]
    mov [rcx + rax], edx
.o:
    ret

; ---------------------------------------------------------------------------
; edi=x esi=y edx=w ecx=h r8d=color  (clipped, per-row rep stosd)
gfx_fill_rect:
    push rbx
    push r12
    push r13
    push r14
    push r15
    test edx, edx
    jle .done
    test ecx, ecx
    jle .done
    mov r12d, r8d               ; color
    ; clip x
    test edi, edi
    jns .x0
    add edx, edi
    xor edi, edi
    jmp .xw
.x0:
    cmp edi, [fb_width]
    jb .xw
    jmp .done
.xw:
    test edx, edx
    jle .done
    mov eax, [fb_width]
    sub eax, edi
    jle .done
    cmp edx, eax
    jbe .xk
    mov edx, eax
.xk:
    mov r14d, edx               ; w
    ; clip y
    test esi, esi
    jns .y0
    add ecx, esi
    xor esi, esi
    jmp .yw
.y0:
    cmp esi, [fb_height]
    jb .yw
    jmp .done
.yw:
    test ecx, ecx
    jle .done
    mov eax, [fb_height]
    sub eax, esi
    jle .done
    cmp ecx, eax
    jbe .yk
    mov ecx, eax
.yk:
    mov r15d, ecx               ; h
    mov r13, [bb_addr]
    mov eax, [fb_pitch]
    imul rax, rsi
    add r13, rax
    lea r13, [r13 + rdi*4]      ; x offset in bytes (4 bpp)
.row:
    mov rdi, r13
    mov ecx, r14d
    mov eax, r12d
    rep stosd
    mov eax, [fb_pitch]
    add r13, rax
    dec r15d
    jnz .row
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; edi=x esi=y edx=len ecx=color
gfx_hline:
    push rdx
    push rcx
    mov r8d, ecx                ; color
    mov ecx, 1                  ; h=1
    call gfx_fill_rect
    pop rcx
    pop rdx
    ret

; ---------------------------------------------------------------------------
; edi=x esi=y edx=w ecx=h r8d=radius r9d=color (filled rounded rect)
gfx_fill_roundrect:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov [rsp], edx              ; w
    mov r12d, r8d               ; r
    mov r13d, ecx               ; h
    mov r14d, edi               ; x
    mov r15d, esi               ; y
    mov ebx, r9d                ; color
    cmp r12d, 0
    jle .plain
    ; middle band
    mov edi, r14d
    mov esi, r15d
    add esi, r12d
    mov edx, [rsp]
    mov ecx, r13d
    sub ecx, r12d
    sub ecx, r12d
    jle .corners                ; too flat for a band
    mov r8d, ebx
    call gfx_fill_rect
.corners:
    xor r11d, r11d              ; dy = 0..r-1
.row:
    cmp r11d, r12d
    jae .done
    ; inset = r - isqrt(r*r - (r-dy)^2)
    mov eax, r12d
    imul eax, eax
    mov edi, r12d
    sub edi, r11d
    imul edi, edi
    sub eax, edi
    mov edi, eax
    call gfx_isqrt
    mov r10d, r12d
    sub r10d, eax               ; inset
    ; len = w - 2*inset
    mov eax, [rsp]
    sub eax, r10d
    sub eax, r10d
    jle .next
    ; top hline
    mov edi, r14d
    add edi, r10d
    mov esi, r15d
    add esi, r11d
    mov edx, eax
    mov ecx, ebx
    call gfx_hline
    ; bottom hline
    mov edi, r14d
    add edi, r10d
    mov esi, r15d
    add esi, r13d
    dec esi
    sub esi, r11d
    mov eax, [rsp]
    sub eax, r10d
    sub eax, r10d
    mov edx, eax
    mov ecx, ebx
    call gfx_hline
.next:
    inc r11d
    jmp .row
.plain:
    mov edi, r14d
    mov esi, r15d
    mov edx, [rsp]
    mov ecx, r13d
    mov r8d, ebx
    call gfx_fill_rect
.done:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ---------------------------------------------------------------------------
; edi=n -> eax = isqrt(n)
gfx_isqrt:
    push rcx
    push rdx
    push r10
    xor eax, eax
    test edi, edi
    jz .done                 ; isqrt(0) = 0 (Newton loop would div-by-0)
    mov ecx, edi
    shr ecx, 1
    jnz .have
    mov ecx, 1
.have:
    mov r10d, 8
.it:
    mov eax, edi
    xor edx, edx
    div ecx
    add eax, ecx
    shr eax, 1
    mov ecx, eax
    dec r10d
    jnz .it
.adj:
    mov eax, ecx
    imul eax, ecx
    cmp eax, edi
    jbe .ok
    dec ecx
    jmp .adj
.ok:
    mov eax, ecx
.done:
    pop r10
    pop rdx
    pop rcx
    ret

; ---------------------------------------------------------------------------
; edi=x esi=y dl=char ecx=color
gfx_draw_char:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12d, edi               ; x
    mov r13d, esi               ; y
    mov r14d, ecx               ; color
    movzx eax, dl
    cmp eax, 32
    jae .r1
    mov eax, '?'
    jmp .r2
.r1:
    cmp eax, 126
    jbe .r2
    mov eax, '?'
.r2:
    sub eax, 32
    imul rax, rax, 16
    lea r11, [font_data]
    add r11, rax                ; glyph ptr (rdx is clobbered by color arg below)
    mov r15d, 16                ; rows
.rloop:
    mov al, [r11]
    mov r8d, r12d               ; px x
    mov r9d, 8                  ; cols
    mov r10b, al
.bloop:
    test r10b, 0x80
    jz .bnext
    mov edi, r8d
    mov esi, r13d
    mov edx, r14d
    call gfx_px
.bnext:
    shl r10b, 1
    inc r8d
    dec r9d
    jnz .bloop
    inc r13d
    inc r11
    dec r15d
    jnz .rloop
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; edi=x esi=y rdx=ptr ecx=color
gfx_draw_string:
    push rbx
    push r12
    push r13
    push r14
    mov r12d, edi               ; x
    mov r13d, esi               ; y
    mov ebx, ecx                ; color
    mov r14, rdx                ; string ptr (gfx_draw_char clobbers rdx)
.l:
    movzx eax, byte [r14]
    test al, al
    jz .d
    mov edi, r12d
    mov esi, r13d
    mov dl, al
    mov ecx, ebx
    call gfx_draw_char
    inc r14
    add r12d, 8
    jmp .l
.d:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; edi=x esi=y r8d=value ecx=color
gfx_draw_uint:
    push rbx
    push r12
    push r13
    sub rsp, 32
    mov r12d, edi               ; x
    mov r13d, esi               ; y
    mov ebx, ecx                ; color
    mov edi, r8d                ; value
    mov rsi, rsp
    call u32_to_str
    mov edi, r12d
    mov esi, r13d
    mov rdx, rax
    mov ecx, ebx
    call gfx_draw_string
    add rsp, 32
    pop r13
    pop r12
    pop rbx
    ret

; ---------------------------------------------------------------------------
; rdi=value rsi=buf(>=13B) -> rax = pointer to first digit
u32_to_str:
    push rdx
    push rcx
    push r8
    mov eax, edi
    lea rcx, [rsi + 12]
    mov byte [rcx], 0
    mov r8, rcx
.d:
    xor edx, edx
    mov r9d, 10
    div r9d
    add dl, '0'
    dec r8
    mov [r8], dl
    test eax, eax
    jnz .d
    mov rax, r8
    pop r8
    pop rcx
    pop rdx
    ret

; ---------------------------------------------------------------------------
; aurora_buf -> bb_addr (contiguous width*height dwords)
gfx_restore_bg:
    push rcx
    push rsi
    push rdi
    mov rsi, [aurora_buf]
    mov rdi, [bb_addr]
    mov ecx, [fb_width]
    imul ecx, [fb_height]
    rep movsd
    pop rdi
    pop rsi
    pop rcx
    ret

; bb_addr -> real framebuffer (handles pitch != width*4)
gfx_present:
    push r12
    push r13
    push r14
    push r15
    mov rsi, [bb_addr]
    mov rdi, [fb_addr]
    mov r12d, [fb_width]
    mov r13d, [fb_height]
    mov eax, r12d
    shl eax, 2
    cmp eax, [fb_pitch]
    jne .rows
    mov ecx, r12d
    imul ecx, r13d
    rep movsd
    jmp .d
.rows:
    xor r14d, r14d
.row:
    mov ecx, r12d
    rep movsd
    mov eax, r12d
    shl eax, 2
    mov r15d, [fb_pitch]
    sub r15d, eax
    add rdi, r15
    inc r14d
    cmp r14d, r13d
    jb .row
.d:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; ---------------------------------------------------------------------------
; edi=cx esi=cy edx=r ecx=color (filled circle via per-row hlines)
gfx_fill_circle:
    push r12
    push r13
    push r14
    push r15
    push r10
    test edx, edx
    jle .done
    mov r12d, edi               ; cx
    mov r13d, esi               ; cy
    mov r14d, edx               ; r
    mov r15d, ecx               ; color
    mov eax, r14d
    neg eax
    mov r10d, eax               ; dy = -r
.loop:
    mov edi, r14d
    imul edi, edi
    mov eax, r10d
    imul eax, eax
    sub edi, eax                ; r*r - dy*dy
    call gfx_isqrt              ; eax = isqrt
    mov ecx, r14d
    sub ecx, eax                ; inset
    mov eax, r14d
    sub eax, ecx                ; half-span
    mov edx, eax
    add edx, edx                ; len = 2*half-span
    mov esi, r13d
    add esi, r10d               ; y = cy + dy
    mov edi, r12d
    sub edi, eax                ; x = cx - half-span
    mov ecx, r15d
    call gfx_hline
    inc r10d
    cmp r10d, r14d
    jle .loop
.done:
    pop r10
    pop r15
    pop r14
    pop r13
    pop r12
    ret
