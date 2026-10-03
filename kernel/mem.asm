; =============================================================================
; AURA-OS v2 — kernel/mem.asm
; Physical memory manager: 4 GiB bitmap (1 bit / 4 KiB page = 128 KiB, in bss).
; Seeded from stage2's e820 map at 0x5100, kernel pages pre-marked used.
; =============================================================================
mem_init:
    ; bitmap: everything used
    mov rdi, pmm_bitmap
    mov rcx, 131072 / 8
    mov rax, 0xFFFFFFFFFFFFFFFF
    rep stosq

    ; walk e820 (24 B entries @ 0x5100, count @ 0x5018)
    mov r13d, [0x5018]
    test r13d, r13d
    jz .seed_done
    mov rsi, 0x5100
.ent:
    mov rdx, [rsi + 16]         ; type
    cmp rdx, 1                  ; usable RAM
    jne .next
    mov rax, [rsi]              ; base
    mov rbx, [rsi + 8]          ; len
    add rbx, rax                ; end (exclusive)
    cmp rax, 0x100000
    jae .s_ok
    mov rax, 0x100000
.s_ok:
    cmp rbx, 0x40000000
    jbe .e_ok
    mov rbx, 0x40000000
.e_ok:
    shr rax, 12                 ; start page
    shr rbx, 12                 ; end page (exclusive)
    cmp rax, rbx
    jae .next
.pg:
    mov r8, rax
    shr r8, 3
    add r8, pmm_bitmap
    mov ecx, eax
    and ecx, 7
    mov r9, 1
    shl r9, cl
    not r9
    and [r8], r9
    inc dword [pmm_free_pages]
    inc rax
    cmp rax, rbx
    jb .pg
.next:
    add rsi, 24
    dec r13d
    jnz .ent
.seed_done:
    ; mark kernel+bss+boot stack used: pages [0x100000>>12, bss_end+64K up)
    mov rax, 0x100000
    shr rax, 12
    mov rbx, bss_end
    add rbx, 0x10000            ; boot stack lives here — must stay reserved
    add rbx, 0xFFF
    shr rbx, 12
    call pmm_mark_range
    ; subtract kernel pages from free count (recount honestly)
    mov rax, rbx
    sub rax, 256
    sub [pmm_free_pages], rax
    ret

; rax = start page, rbx = end page (exclusive) -> set used
pmm_mark_range:
    push rax
    push rbx
    push rcx
    push r8
    push r9
    cmp rax, rbx
    jae .d
.l:
    mov r8, rax
    shr r8, 3
    add r8, pmm_bitmap
    mov ecx, eax
    and ecx, 7
    mov r9, 1
    shl r9, cl
    or [r8], r9
    inc rax
    cmp rax, rbx
    jb .l
.d:
    pop r9
    pop r8
    pop rcx
    pop rbx
    pop rax
    ret

; rdi = page count -> rax = physical address, or 0
pmm_alloc_run:
    push rbp
    push rsi
    push rdx
    push rcx
    push rbx
    push r8
    push r9
    mov rbp, rdi
    xor rsi, rsi                ; page index
    xor rdx, rdx                ; current run length
    xor r8, r8                  ; run start
.l:
    cmp rsi, 1048576            ; 4 GiB / 4 KiB
    jae .fail
    mov r10, rsi
    shr r10, 3
    add r10, pmm_bitmap         ; r10 = &bitmap[page >> 3]
    mov eax, esi
    and eax, 7
    mov cl, al
    mov r9, 1
    shl r9, cl
    test byte [r10], r9b
    jnz .used
    test rdx, rdx
    jnz .cont
    mov r8, rsi
.cont:
    inc rdx
    cmp rdx, rbp
    jae .found
    inc rsi
    jmp .l
.used:
    xor rdx, rdx
    inc rsi
    jmp .l
.found:
    ; mark [r8, r8+rbp) used
    mov rax, r8
    lea rbx, [r8 + rbp]
    call pmm_mark_range
    mov rax, r8
    shl rax, 12
    sub [pmm_free_pages], rbp
    jmp .out
.fail:
    xor eax, eax
.out:
    pop r9
    pop r8
    pop rbx
    pop rcx
    pop rdx
    pop rsi
    pop rbp
    ret
