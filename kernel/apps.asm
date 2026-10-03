; =============================================================================
; AURA-OS v2 — kernel/apps.asm
; Built-in apps drawn inside windows: 1=About, 2=Editor, 3=Terminal.
; Window manager primitive (win_open) + terminal command interpreter.
; NOTE: keep all db data AFTER code blocks (local labels attach to the
; most recent non-local label).
; =============================================================================

apps_init:
    mov rdi, 3                  ; Terminal
    call win_open
    ret

; rdi = app id (1..3) -> open (or raise) its window
win_open:
    push rbx
    push r12
    mov r12d, edi
    dec r12d                    ; slot index 0..2
    mov ebx, r12d
    imul ebx, ebx, 48
    lea rdi, [windows]
    add rdi, rbx
    cmp dword [rdi + W_W], 0
    jne .show
    ; first open: copy geometry + title (16 B each, slot-indexed)
    mov eax, r12d
    shl eax, 4
    lea rsi, [geo_tab]
    add rsi, rax
    mov rax, [rsi]
    mov [rdi + W_X], rax
    mov rax, [rsi + 8]
    mov [rdi + W_W], rax
    lea rsi, [title_tab]
    mov eax, r12d
    shl eax, 4
    add rsi, rax
    mov rax, [rsi]
    mov [rdi + W_TITLE], rax
    mov rax, [rsi + 8]
    mov [rdi + W_TITLE + 8], rax
.show:
    push rdi
    call gui_unfocus_all
    pop rdi
    mov byte [rdi + W_VIS], 1
    mov byte [rdi + W_FOC], 1
    inc dword [win_ztop]
    mov eax, [win_ztop]
    mov [rdi + W_Z], eax
    mov byte [dirty], 1
    pop r12
    pop rbx
    ret

; =============================================================================
; rdi = window -> draw app content (dispatch)
; =============================================================================
app_draw:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov eax, [rbx + W_APP]
    cmp eax, 1
    je app_draw_about
    cmp eax, 2
    je app_draw_edit
    jmp app_draw_term           ; term falls through into app_draw_out
about_jmp:

; ---- About ----
app_draw_about:
    mov r12d, [rbx + W_X]
    add r12d, 16
    mov r13d, [rbx + W_Y]
    add r13d, 44
    mov edi, r12d
    mov esi, r13d
    lea rdx, [s_a1]
    mov ecx, C_TXT
    call gfx_draw_string
    lea rdi, [a_lines]
    mov r14d, 3                 ; remaining dim lines
.al:
    test r14d, r14d
    jz .adyn
    add r13d, 20
    mov edi, r12d
    mov esi, r13d
    mov rdx, [rdi]
    mov ecx, C_TXT_DIM
    call gfx_draw_string
    add rdi, 8
    dec r14d
    jmp .al
.adyn:
    ; dynamic lines
    add r13d, 36
    mov edi, r12d
    mov esi, r13d
    lea rdx, [s_dmem]
    mov ecx, C_TXT_DIM
    call gfx_draw_string
    mov edi, r12d
    add edi, 72
    mov r8d, [pmm_free_pages]
    shr r8d, 8                  ; pages -> MB
    mov ecx, C_TXT
    call gfx_draw_uint
    add r13d, 20
    mov edi, r12d
    mov esi, r13d
    lea rdx, [s_dupt]
    mov ecx, C_TXT_DIM
    call gfx_draw_string
    mov edi, r12d
    add edi, 80
    mov eax, [pit_ticks]
    xor edx, edx
    mov ecx, 100
    div ecx
    mov r8d, eax                ; uptime seconds
    mov ecx, C_TXT
    call gfx_draw_uint
    jmp app_draw_out

; ---- Editor ----
app_draw_edit:
    mov eax, [rbx + W_W]
    sub eax, 32
    shr eax, 3
    jg .eok
    xor eax, eax
.eok:
    mov r12d, eax               ; chars per row
    mov r15d, [rbx + W_X]
    add r15d, 16
    mov r13d, [rbx + W_Y]
    add r13d, 40
    xor r14d, r14d              ; index into edit_buf
.el:
    cmp r14d, [edit_len]
    jae app_draw_out
    mov ecx, r14d
    movzx eax, byte [edit_buf + rcx]
    cmp eax, 10
    je .enl
    mov edi, r15d
    mov esi, r13d
    mov dl, al
    mov ecx, C_TXT
    call gfx_draw_char
    add r15d, 8
    inc r14d
    ; wrap at content width
    mov eax, r15d
    sub eax, [rbx + W_X]
    sub eax, 16
    shr eax, 3
    cmp eax, r12d
    jb .el
    mov r15d, [rbx + W_X]
    add r15d, 16
    add r13d, 16
    jmp .el
.enl:
    inc r14d
    mov r15d, [rbx + W_X]
    add r15d, 16
    add r13d, 16
    jmp .el

; ---- Terminal ----
app_draw_term:
    ; visible rows N = (h-56)/16
    mov eax, [rbx + W_H]
    sub eax, 56
    cmp eax, 0
    jle .tn
    shr eax, 4
    jmp .tn0
.tn:
    xor eax, eax
.tn0:
    ; start row = max(0, term_lines - N)
    mov ecx, [term_lines]
    sub ecx, eax
    jns .ts0
    xor ecx, ecx
.ts0:
    mov r12d, ecx               ; start row
    mov r15d, [rbx + W_X]
    add r15d, 16
    mov r13d, [rbx + W_Y]
    add r13d, 34
    mov r14d, ecx               ; current row
.tr:
    cmp r14d, [term_lines]
    jae .tprompt
    mov eax, r14d
    sub eax, r12d
    shl eax, 4
    add eax, r13d
    mov esi, eax
    mov edi, r15d
    mov ecx, r14d
    imul ecx, ecx, 96
    lea rdx, [term_buf + rcx]
    mov ecx, C_TXT
    call gfx_draw_string
    inc r14d
    jmp .tr
.tprompt:
    mov eax, [term_lines]
    sub eax, r12d
    shl eax, 4
    add eax, r13d
    mov esi, eax
    mov edi, r15d
    lea rdx, [s_prompt]
    mov ecx, C_TXT
    call gfx_draw_string
    mov edi, r15d
    add edi, 16
    lea rdx, [term_line]
    mov ecx, C_TXT
    call gfx_draw_string
    ; block cursor
    mov ecx, [term_len]
    imul ecx, ecx, 8
    add ecx, 16
    add ecx, r15d
    mov edi, ecx
    mov edx, 7
    mov ecx, 15
    mov r8d, C_TXT
    call gfx_fill_rect

app_draw_out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; =============================================================================
; rdi = window, esi = ascii key
; =============================================================================
apps_key:
    push rbx
    push r12
    mov rbx, rdi
    mov r12d, esi
    mov eax, [rbx + W_APP]
    cmp eax, 3
    je apps_key_term
    cmp eax, 2
    je apps_key_edit
    jmp apps_key_out           ; About: no input

apps_key_term:
    mov eax, r12d
    cmp eax, 8
    je .tbs
    cmp eax, 10
    je .tent
    cmp eax, 32
    jb apps_key_out
    cmp eax, 126
    ja apps_key_out
    mov ecx, [term_len]
    cmp ecx, 90
    jae apps_key_out
    mov [term_line + rcx], al
    inc dword [term_len]
    jmp apps_key_out
.tbs:
    mov ecx, [term_len]
    test ecx, ecx
    jz apps_key_out
    dec ecx
    mov byte [term_line + rcx], 0
    mov [term_len], ecx
    jmp apps_key_out
.tent:
    mov ecx, [term_len]
    mov byte [term_line + rcx], 0
    lea rsi, [term_line]
    call term_push_line
    call term_exec
    mov dword [term_len], 0
    jmp apps_key_out

apps_key_edit:
    mov eax, r12d
    cmp eax, 8
    je .ebs
    cmp eax, 10
    je .enlk
    cmp eax, 32
    jb apps_key_out
    cmp eax, 126
    ja apps_key_out
    mov ecx, [edit_len]
    cmp ecx, 4000
    jae apps_key_out
    mov [edit_buf + rcx], al
    inc dword [edit_len]
    jmp apps_key_out
.ebs:
    mov ecx, [edit_len]
    test ecx, ecx
    jz apps_key_out
    dec ecx
    mov [edit_len], ecx
    jmp apps_key_out
.enlk:
    mov ecx, [edit_len]
    cmp ecx, 4000
    jae apps_key_out
    mov byte [edit_buf + rcx], 10
    inc dword [edit_len]

apps_key_out:
    pop r12
    pop rbx
    ret

; =============================================================================
term_exec:
    push rbx
    push r12
    cmp byte [term_line], 0
    je .out
    lea rdi, [term_line]
    lea rsi, [s_chelp]
    call streq
    test al, al
    jnz .do_help
    lea rdi, [term_line]
    lea rsi, [s_cclear]
    call streq
    test al, al
    jnz .do_clear
    lea rdi, [term_line]
    lea rsi, [s_cmem]
    call streq
    test al, al
    jnz .do_mem
    lea rdi, [term_line]
    lea rsi, [s_cuptime]
    call streq
    test al, al
    jnz .do_uptime
    lea rdi, [term_line]
    lea rsi, [s_cver]
    call streq
    test al, al
    jnz .do_ver
    lea rdi, [term_line]
    lea rsi, [s_cecho]
    mov rcx, 5
    call strneq
    test al, al
    jnz .do_echo
    lea rsi, [s_unknown]
    call term_push_line
    jmp .out
.do_help:
    lea rsi, [s_h1]
    call term_push_line
    lea rsi, [s_h2]
    call term_push_line
    lea rsi, [s_h3]
    call term_push_line
    lea rsi, [s_h4]
    call term_push_line
    lea rsi, [s_h5]
    call term_push_line
    lea rsi, [s_h6]
    call term_push_line
    lea rsi, [s_h7]
    call term_push_line
    jmp .out
.do_clear:
    mov dword [term_lines], 0
    mov dword [term_len], 0
    jmp .out
.do_mem:
    lea rdi, [term_num]
    lea rsi, [s_free]
    call strcpy
    mov edi, [pmm_free_pages]
    shr edi, 8
    mov rsi, rax
    call u32_to_str
    lea rdi, [term_num]
    call term_push_line
    jmp .out
.do_uptime:
    mov eax, [pit_ticks]
    xor edx, edx
    mov ecx, 100
    div ecx
    mov r12d, eax               ; seconds
    lea rdi, [term_num]
    lea rsi, [s_upt]
    call strcpy
    mov edi, r12d
    mov rsi, rax
    call u32_to_str
    lea rdi, [term_num]
    call term_push_line
    jmp .out
.do_ver:
    lea rsi, [s_ver]
    call term_push_line
    jmp .out
.do_echo:
    lea rdi, [term_line + 5]
    call term_push_line
.out:
    pop r12
    pop rbx
    ret

; -----------------------------------------------------------------------------
; rsi = 0-terminated line -> append to term_buf (shifts when full)
term_push_line:
    push rbx
    push r12
    mov r12, rsi
    mov eax, [term_lines]
    cmp eax, 24
    jb .room
    ; shift all rows up by one
    lea rdi, [term_buf]
    lea rsi, [term_buf + 96]
    mov ecx, 23*96/4
    rep movsd
    mov dword [term_lines], 23
.room:
    mov eax, [term_lines]
    imul eax, eax, 96
    lea rdi, [term_buf + rax]
    mov rsi, r12
    mov ecx, 95
.cp:
    lodsb
    mov [rdi], al
    test al, al
    jz .t
    inc rdi
    dec ecx
    jnz .cp
.t:
    mov byte [rdi], 0
    inc dword [term_lines]
    pop r12
    pop rbx
    ret

; rdi = str, rsi = str -> al = 1 if equal
streq:
    push rdi
    push rsi
.l:
    mov al, [rdi]
    mov dl, [rsi]
    cmp al, dl
    jne .no
    test al, al
    jz .yes
    inc rdi
    inc rsi
    jmp .l
.yes:
    mov al, 1
    pop rsi
    pop rdi
    ret
.no:
    xor eax, eax
    pop rsi
    pop rdi
    ret

; rdi = str, rsi = str, rcx = len -> al = 1 if first rcx bytes equal
strneq:
    push rdi
    push rsi
    push rcx
.l:
    mov al, [rdi]
    mov dl, [rsi]
    cmp al, dl
    jne .no
    inc rdi
    inc rsi
    dec rcx
    jnz .l
    mov al, 1
    pop rcx
    pop rsi
    pop rdi
    ret
.no:
    xor eax, eax
    pop rcx
    pop rsi
    pop rdi
    ret

; rdi = dst, rsi = src -> rax = pointer to dst terminator
strcpy:
    push rdi
.l:
    lodsb
    mov [rdi], al
    test al, al
    jz .d
    inc rdi
    jmp .l
.d:
    mov rax, rdi
    pop rdi
    ret

; =============================================================================
; data
; =============================================================================
s_prompt  db "> ", 0
s_chelp   db "help", 0
s_cclear  db "clear", 0
s_cmem    db "mem", 0
s_cuptime db "uptime", 0
s_cver    db "ver", 0
s_cecho   db "echo ", 0
s_unknown db "unknown command (try help)", 0
s_h1      db "commands:", 0
s_h2      db " help", 0
s_h3      db " clear", 0
s_h4      db " mem", 0
s_h5      db " uptime", 0
s_h6      db " ver", 0
s_h7      db " echo <text>", 0
s_free    db "Free MB: ", 0
s_upt     db "Uptime s: ", 0
s_ver     db "AuraOS 2.0 pure-asm", 0

s_a1   db "AuraOS 2.0", 0
s_a2   db "Pure NASM x86-64 kernel", 0
s_a3   db "From scratch - no OS underneath", 0
s_a4   db "VBE 1024x768x32", 0
s_dmem db "Free MB: ", 0
s_dupt db "Uptime s: ", 0

align 8
a_lines:
    dq s_a2, s_a3, s_a4

geo_tab:
    dd 320, 200, 420, 240       ; About
    dd 200, 120, 620, 420       ; Editor
    dd 280, 140, 560, 380       ; Terminal

align 16
title_tab:
    db "About AuraOS"
    times 4 db 0                ; 12+4 = 16 B per entry
    db "Editor"
    times 10 db 0
    db "Terminal"
    times 8 db 0
