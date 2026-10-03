; =============================================================================
; AURA-OS v2 — kernel/gui.asm
; macOS-style desktop: top menu bar, bottom Dock, draggable windows with
; traffic lights, PS/2 mouse cursor. Redraws off-screen only when dirty.
; =============================================================================

; ---- palette ----
C_BAR        equ 0xFF101014     ; menu bar
C_BAR_LINE   equ 0xFF28282E
C_BAR_TXT    equ 0xFFEBEBF5
C_WIN        equ 0xFF1A1C24     ; window body
C_WIN_TITLE  equ 0xFF262834     ; title bar
C_TXT        equ 0xFFEBEBF5
C_TXT_DIM    equ 0xFF9696A0

BAR_H        equ 24
DOCK_X       equ 422
DOCK_Y       equ 704
DOCK_W       equ 180
DOCK_H       equ 56

gui_init:
    mov dword [mouse_x], 512
    mov dword [mouse_y], 384
    mov dword [win_ztop], 0
    mov dword [drag_win], -1
    mov byte [prev_b], 0
    mov dword [clk_last], 0
    mov dword [term_len], 0
    mov dword [term_lines], 0
    mov dword [edit_len], 0
    call apps_init
    lea rsi, [s_w1]
    call term_push_line
    lea rsi, [s_w2]
    call term_push_line
    ret

s_w1 db "AuraOS terminal", 0
s_w2 db "type help", 0

; =============================================================================
gui_loop:
    call kbd_getkey
    test al, al
    jz .mouse
    movzx r12d, al
    call gui_focus_win          ; rdi = focused window or 0
    test rdi, rdi
    jz .mouse
    mov esi, r12d
    call apps_key               ; rdi = win, esi = ascii
    mov byte [dirty], 1

.mouse:
    movzx eax, byte [mouse_b]
    and eax, 1
    mov ecx, eax                ; left button now
    test ecx, ecx
    jz .release
    cmp byte [prev_b], 0
    jne .drag_chk
    call gui_click              ; fresh press
.drag_chk:
    mov eax, [drag_win]
    cmp eax, -1
    je .held
    ; move dragged window
    imul eax, eax, 48
    lea rdi, [windows]
    add rdi, rax
    mov eax, [mouse_x]
    sub eax, [drag_dx]
    mov [rdi + W_X], eax
    mov eax, [mouse_y]
    sub eax, [drag_dy]
    mov [rdi + W_Y], eax
    mov byte [dirty], 1
    jmp .held
.release:
    mov dword [drag_win], -1
.held:
    movzx eax, byte [mouse_b]
    mov [prev_b], al

.clock:
    mov eax, [pit_ticks]
    xor edx, edx
    mov ecx, 100
    div ecx
    cmp eax, [clk_last]
    je .redraw
    mov [clk_last], eax
    call rtc_read
    mov byte [dirty], 1
.redraw:
    cmp byte [dirty], 0
    je .sleep
    mov byte [dirty], 0
    call gui_redraw
.sleep:
    hlt
    jmp gui_loop

; =============================================================================
gui_redraw:
    push rbp
    mov rbp, rsp
    call gfx_restore_bg
    call gui_draw_windows
    call gui_draw_dock
    call gui_draw_bar
    call gui_draw_cursor
    call gfx_present
    pop rbp
    ret

; ---- top menu bar ----
gui_draw_bar:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    xor edi, edi
    xor esi, esi
    mov edx, [fb_width]
    mov ecx, BAR_H
    mov r8d, C_BAR
    call gfx_fill_rect
    xor edi, edi
    mov esi, BAR_H
    mov edx, [fb_width]
    mov ecx, 1
    mov r8d, C_BAR_LINE
    call gfx_hline
    ; apple-ish dot
    mov edi, 10
    mov esi, 12
    mov edx, 4
    mov ecx, 0xFF508CFF
    call gfx_fill_circle
    ; system name
    mov edi, 20
    mov esi, 4
    lea rdx, [s_sysname]
    mov ecx, C_BAR_TXT
    call gfx_draw_string
    ; clock "HH:MM" at right (build on stack, one gfx_draw_string call;
    ; gfx_draw_char clobbers rdi/rsi so per-char positioning is unsafe)
    mov al, [rtc_h]
    shr al, 4
    add al, '0'
    mov [rsp], al
    mov al, [rtc_h]
    and al, 0x0F
    add al, '0'
    mov [rsp + 1], al
    mov byte [rsp + 2], ':'
    mov al, [rtc_m]
    shr al, 4
    add al, '0'
    mov [rsp + 3], al
    mov al, [rtc_m]
    and al, 0x0F
    add al, '0'
    mov [rsp + 4], al
    mov byte [rsp + 5], 0
    mov edi, [fb_width]
    sub edi, 48                 ; 5 chars * 8 + 8 margin
    mov esi, 4
    lea rdx, [rsp]
    mov ecx, C_BAR_TXT
    call gfx_draw_string
    leave
    ret

s_sysname db "AuraOS", 0

; ---- dock ----
icon_cols dd 0xFF3C78E6, 0xFF32B45A, 0xFF5A5A64
icon_chars db "AET"

gui_draw_dock:
    push rbx
    push rbp
    mov rbp, rsp
    mov edi, DOCK_X
    mov esi, DOCK_Y
    mov edx, DOCK_W
    mov ecx, DOCK_H
    mov r8d, 14
    mov r9d, 0xFF262834
    call gfx_fill_roundrect
    xor ebx, ebx
.il:
    cmp ebx, 3
    jae .d
    ; icon body
    imul eax, ebx, 52
    add eax, DOCK_X + 12
    mov r10d, eax
    lea r9, [icon_cols]
    mov r9d, [r9 + rbx*4]
    mov edi, r10d
    mov esi, DOCK_Y + 8
    mov edx, 40
    mov ecx, 40
    mov r8d, 10
    call gfx_fill_roundrect
    ; letter
    imul eax, ebx, 52
    add eax, DOCK_X + 12 + 16
    mov edi, eax
    mov esi, DOCK_Y + 8 + 12
    movzx edx, byte [icon_chars + rbx]
    mov ecx, 0xFFFFFFFF
    call gfx_draw_char
    inc ebx
    jmp .il
.d:
    pop rbp
    pop rbx
    ret

; ---- windows ----
gui_draw_windows:
    push rbx
    push r12
    mov r12d, 1                 ; z from 1..win_ztop
.zl:
    mov eax, [win_ztop]
    cmp r12d, eax
    ja .done
    xor ebx, ebx
.wl:
    cmp ebx, 8
    jae .wn
    mov eax, ebx
    imul eax, eax, 48
    lea rdi, [windows]
    add rdi, rax
    cmp byte [rdi + W_VIS], 0
    je .next
    cmp [rdi + W_Z], r12d
    jne .next
    call gui_draw_win
.next:
    inc ebx
    jmp .wl
.wn:
    inc r12d
    jmp .zl
.done:
    pop r12
    pop rbx
    ret

; rdi = window
gui_draw_win:
    push rbx
    mov rbx, rdi
    ; body
    mov edi, [rbx + W_X]
    mov esi, [rbx + W_Y]
    mov edx, [rbx + W_W]
    mov ecx, [rbx + W_H]
    mov r8d, 10
    mov r9d, C_WIN
    call gfx_fill_roundrect
    ; title bar (rounded top, square bottom via patch rect)
    mov edi, [rbx + W_X]
    mov esi, [rbx + W_Y]
    mov edx, [rbx + W_W]
    mov ecx, 28
    mov r8d, 10
    mov r9d, C_WIN_TITLE
    call gfx_fill_roundrect
    mov edi, [rbx + W_X]
    mov esi, [rbx + W_Y]
    add esi, 20
    mov edx, [rbx + W_W]
    mov ecx, 8
    mov r8d, C_WIN_TITLE
    call gfx_fill_rect
    ; traffic lights
    mov edi, [rbx + W_X]
    add edi, 14
    mov esi, [rbx + W_Y]
    add esi, 14
    mov edx, 5
    mov ecx, 0xFFFF5F56
    call gfx_fill_circle
    mov edi, [rbx + W_X]
    add edi, 32
    mov esi, [rbx + W_Y]
    add esi, 14
    mov edx, 5
    mov ecx, 0xFFFFBD2E
    call gfx_fill_circle
    mov edi, [rbx + W_X]
    add edi, 50
    mov esi, [rbx + W_Y]
    add esi, 14
    mov edx, 5
    mov ecx, 0xFF27C93F
    call gfx_fill_circle
    ; title text
    mov edi, [rbx + W_X]
    add edi, 62
    mov esi, [rbx + W_Y]
    add esi, 7
    lea rdx, [rbx + W_TITLE]
    mov ecx, C_TXT_DIM
    call gfx_draw_string
    ; app content
    mov rdi, rbx
    call app_draw
    pop rbx
    ret

; ---- mouse cursor (12x18 arrow: shadow + white) ----
CUSR_W equ 12
CUSR_H equ 18
cursor_bm:
    dw 0x8000, 0xC000, 0xE000, 0xF000, 0xF800, 0xFC00
    dw 0xFE00, 0xFF00, 0xFF80, 0xFFC0, 0xFFE0, 0xFFFF
    dw 0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000

; rdi=x rsi=y edx=color
cursor_draw:
    push r12
    push r13
    push r14
    push rbx                    ; row bitmap (gfx_px clobbers rax/rcx/rdx)
    push r9
    push r10
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    xor r10d, r10d              ; row
.row:
    movzx ebx, word [cursor_bm + r10*2]
    shl ebx, 16
    xor r9d, r9d                ; col
.col:
    shl ebx, 1
    jnc .cn
    lea edi, [r12 + r9]
    lea esi, [r13 + r10]
    mov edx, r14d
    call gfx_px
.cn:
    inc r9d
    cmp r9d, CUSR_W
    jb .col
    inc r10d
    cmp r10d, CUSR_H
    jb .row
    pop r10
    pop r9
    pop rbx
    pop r14
    pop r13
    pop r12
    ret

gui_draw_cursor:
    mov edi, [mouse_x]
    mov esi, [mouse_y]
    inc edi
    inc esi
    mov edx, 0xFF000000         ; black shadow
    call cursor_draw
    mov edi, [mouse_x]
    mov esi, [mouse_y]
    mov edx, 0xFFF5F5F7         ; white arrow
    call cursor_draw
    ret

; =============================================================================
; input routing helpers
; =============================================================================
; returns rdi = first visible+focused window, or 0
gui_focus_win:
    push rbx
    push rcx
    xor ecx, ecx
.l:
    cmp ecx, 8
    jae .none
    mov eax, ecx
    imul eax, eax, 48
    lea rdi, [windows]
    add rdi, rax
    cmp byte [rdi + W_VIS], 0
    je .n
    cmp byte [rdi + W_FOC], 0
    je .n
    pop rcx
    pop rbx
    ret
.n:
    inc ecx
    jmp .l
.none:
    xor edi, edi
    pop rcx
    pop rbx
    ret

gui_unfocus_all:
    push rcx
    push rdx
    xor ecx, ecx
    lea rdx, [windows]
.l:
    cmp ecx, 8
    jae .d
    mov byte [rdx + W_FOC], 0
    add rdx, 48
    inc ecx
    jmp .l
.d:
    pop rdx
    pop rcx
    ret

; fresh left click at (mouse_x, mouse_y):
; 1) traffic-light close  2) dock icons  3) hit topmost window -> focus+drag
gui_click:
    push rbx
    push r8
    push r9
    ; ---- 1. close buttons ----
    xor ebx, ebx
.cl:
    cmp ebx, 8
    jae .dock
    mov eax, ebx
    imul eax, eax, 48
    lea rdi, [windows]
    add rdi, rax
    cmp byte [rdi + W_VIS], 0
    je .cln
    mov eax, [rdi + W_X]
    lea ecx, [eax + 8]
    cmp [mouse_x], ecx
    jl .cln
    lea ecx, [eax + 56]
    cmp [mouse_x], ecx
    jg .cln
    mov eax, [rdi + W_Y]
    lea ecx, [eax + 8]
    cmp [mouse_y], ecx
    jl .cln
    lea ecx, [eax + 20]
    cmp [mouse_y], ecx
    jg .cln
    mov byte [rdi + W_VIS], 0
    mov byte [dirty], 1
    jmp .out
.cln:
    inc ebx
    jmp .cl
    ; ---- 2. dock ----
.dock:
    xor ebx, ebx
.dk:
    cmp ebx, 3
    jae .wins
    imul eax, ebx, 52
    add eax, DOCK_X + 12
    cmp [mouse_x], eax
    jl .dkn
    add eax, 40
    cmp [mouse_x], eax
    jg .dkn
    cmp dword [mouse_y], DOCK_Y + 8
    jl .dkn
    cmp dword [mouse_y], DOCK_Y + 48
    jg .dkn
    lea rdi, [rbx + 1]
    call win_open
    jmp .out
.dkn:
    inc ebx
    jmp .dk
    ; ---- 3. topmost window hit ----
.wins:
    mov r8d, -1                 ; best slot
    mov r9d, 0                  ; best z
    xor ebx, ebx
.wl:
    cmp ebx, 8
    jae .wf
    mov eax, ebx
    imul eax, eax, 48
    lea rdi, [windows]
    add rdi, rax
    cmp byte [rdi + W_VIS], 0
    je .wn
    mov eax, [rdi + W_Z]
    cmp eax, r9d
    jbe .wn
    mov eax, [rdi + W_X]
    cmp [mouse_x], eax
    jl .wn
    mov ecx, [rdi + W_W]
    add ecx, eax
    cmp [mouse_x], ecx
    jge .wn
    mov eax, [rdi + W_Y]
    cmp [mouse_y], eax
    jl .wn
    mov ecx, [rdi + W_H]
    add ecx, eax
    cmp [mouse_y], ecx
    jge .wn
    mov r9d, [rdi + W_Z]
    mov r8d, ebx
.wn:
    inc ebx
    jmp .wl
.wf:
    cmp r8d, -1
    je .out
    imul ebx, r8d, 48
    lea rdi, [windows]
    add rdi, rbx
    push rdi
    call gui_unfocus_all
    pop rdi
    inc dword [win_ztop]
    mov eax, [win_ztop]
    mov [rdi + W_Z], eax
    mov byte [rdi + W_FOC], 1
    mov eax, [mouse_x]
    sub eax, [rdi + W_X]
    mov [drag_dx], eax
    mov eax, [mouse_y]
    sub eax, [rdi + W_Y]
    mov [drag_dy], eax
    mov [drag_win], r8d
    mov byte [dirty], 1
.out:
    pop r9
    pop r8
    pop rbx
    ret
