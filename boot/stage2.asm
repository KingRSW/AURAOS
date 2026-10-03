; =============================================================================
; AURA-OS v2 — boot/stage2.asm
; Real-mode stage: e820 memory map, VBE 1024x768x32 LFB, kernel load
; (LBA 64 -> 0x10000), A20, protected mode (copy kernel to 0x100000),
; paging (identity 0-4 GiB, 2 MiB pages), long mode, jump to kernel.
;
; Low-memory layout:
;   0x5000  BOOTINFO (passed to kernel)
;   0x5100  e820 entries (24 B each, max 64)
;   0x6000  VBE info block
;   0x6400  VBE mode info block
;   0x7000  MBR DAP (used by mbr)
;   0x7C00  MBR / PM stack top
;   0x7E00  this stage
;   0x10000 kernel staging buffer
;   0x8000  page tables (PML4/PDPT/PD0-3, 6 KiB)
;   0x100000 kernel final address (header: 'AKRN', size32, 8B rsvd; entry +0x10)
; =============================================================================
BITS 16
ORG 0x7E00

KERNEL_LBA      equ 64
E820_MAX        equ 64

; BOOTINFO offsets
BI_FB_ADDR      equ 0x00        ; dq
BI_FB_PITCH     equ 0x08        ; dd
BI_FB_WIDTH     equ 0x0C        ; dd
BI_FB_HEIGHT    equ 0x10        ; dd
BI_FB_BPP       equ 0x14        ; dd
BI_E820_COUNT   equ 0x18        ; dd
BI_BOOT_DRIVE   equ 0x1C        ; db
BI_KERN_SIZE    equ 0x20        ; dd

stage2_start:
    ; zero BOOTINFO (0x5000..0x5027) so all fields start clean
    mov di, 0x5000
    mov cx, 20
    xor ax, ax
    rep stosw
    mov [0x501C], dl                ; boot drive -> BOOTINFO
    cld
    call s2_ser_init
    mov si, s2_on
    call s2_sers
    mov si, s2_hello
    call bios_print

    ; ---------------- e820 memory map -> 0x5100 ----------------
    mov di, 0x5100
    xor ebx, ebx
    xor bp, bp
.e820_loop:
    mov eax, 0xE820
    mov ecx, 24
    mov edx, 0x534D4150
    int 0x15
    jc  .e820_done
    cmp eax, 0x534D4150
    jne .e820_done
    add di, 24
    inc bp
    cmp bp, E820_MAX
    jae .e820_done
    test ebx, ebx
    jz  .e820_done                  ; ebx == 0 -> last entry already stored
    jmp .e820_loop
.e820_done:
    mov [0x5018], bp
    mov si, s2_e820
    call bios_print
    mov al, 'E'
    call s2_serc

    ; ---------------- kernel header (LBA 64, 2 sectors -> 0x10000) ----------------
    mov si, dap_kern
    mov word [dap_kern + 2], 2
    mov word [dap_kern + 4], 0
    mov word [dap_kern + 6], 0x1000
    mov dword [dap_kern + 8], KERNEL_LBA
    mov dl, [0x501C]
    mov ah, 0x42
    int 0x13
    jc  disk_error
    mov al, 'H'
    call s2_serc

    ; check header (0x10000 = 0x1000:0000; 16-bit disp can't reach 0x10000)
    mov ax, 0x1000
    mov fs, ax
    cmp dword [fs:0x0], 0x4E524B41  ; 'AKRN'
    jne bad_kernel
    mov eax, [fs:0x4]               ; kernel file size
    test eax, eax
    jz  bad_kernel
    mov [0x5020], eax
    mov al, 'S'
    call s2_serc

    ; remaining sectors
    mov ecx, eax
    add ecx, 511
    shr ecx, 9                      ; total sectors
    sub ecx, 2
    jbe .kern_loaded
    mov ebx, KERNEL_LBA + 2         ; current LBA
    mov dword [kern_off], 0x400     ; byte offset in staging buffer
.kern_read:
    cmp ecx, 127
    jbe .last
    mov bp, 127
    jmp .go
.last:
    mov bp, cx
.go:
    mov [dap_kern + 2], bp
    mov word [dap_kern + 4], 0
    mov eax, [kern_off]
    shr eax, 4                      ; offset is 512-aligned -> fits segment math
    add eax, 0x1000
    mov [dap_kern + 6], ax
    mov [dap_kern + 8], ebx
    mov dl, [0x501C]
    mov ah, 0x42
    int 0x13
    jc  disk_error
    mov al, 'L'
    call s2_serc
    mov eax, ebp                    ; batch count (BP survives INT 13h)
    add ebx, eax                    ; LBA += n
    shl eax, 9
    add [kern_off], eax             ; offset += n*512
    sub ecx, ebp
    jnz .kern_read
.kern_loaded:
    mov al, 'K'
    call s2_serc
    mov si, s2_kern
    call bios_print

    ; ---------------- A20 ----------------
    mov ax, 0x2401
    int 0x15
    in  al, 0x92
    or  al, 2
    and al, 0xFE
    out 0x92, al
    mov al, 'a'
    call s2_serc

    ; ---------------- VBE ----------------
    mov si, s2_vbe
    call bios_print
    mov di, 0x6000
    mov ax, 0x4F00
    int 0x10
    cmp ax, 0x004F
    jne vbe_error
    mov al, '1'
    call s2_serc
    cmp dword [0x6000], 0x41534556  ; 'VESA'
    jne vbe_error
    mov al, '2'
    call s2_serc

    mov ax, [0x6010]                ; VideoModePtr segment
    mov es, ax
    mov di, [0x600E]                ; VideoModePtr offset
.mode_scan:
    mov cx, [es:di]
    cmp cx, 0xFFFF
    je  .mode_done
    add di, 2
    push es
    push di
    push cx
    mov di, 0x6400
    mov ax, 0x4F01
    int 0x10
    pop cx
    pop di
    pop es
    cmp ax, 0x004F
    jne .mode_scan
    test word [0x6400], 0x10        ; graphics mode
    jz  .mode_scan
    test word [0x6400], 0x80        ; linear framebuffer available (attr bit 7)
    jz  .mode_scan
    cmp byte [0x6400 + 0x19], 32    ; bpp == 32
    jne .mode_scan
    cmp word [0x6400 + 0x12], 1024  ; width
    jne .mode_scan
    cmp word [0x6400 + 0x14], 768   ; height
    jne .mode_scan
    mov [mode_best], cx
    jmp .mode_done
.mode_done:
    mov ax, [mode_best]
    test ax, ax
    jz  vbe_error
    mov al, '3'
    call s2_serc
    mov ax, [mode_best]
    or  ax, 0x4000                  ; LFB bit
    mov bx, ax
    mov ax, 0x4F02
    int 0x10
    cmp ax, 0x004F
    jne vbe_error
    mov al, '4'
    call s2_serc

    ; framebuffer info from last 4F01 result (mode info block @0x6400)
    mov eax, [0x6400 + 0x28]        ; PhysBasePtr
    mov [0x5000], eax
    mov eax, [0x6400 + 0x2C]
    mov [0x5004], eax
    mov ax, [0x6400 + 0x10]         ; bytes per scanline
    mov [0x5008], ax
    mov ax, [0x6400 + 0x12]         ; width
    mov [0x500C], ax
    mov ax, [0x6400 + 0x14]         ; height
    mov [0x5010], ax
    mov al, [0x6400 + 0x19]         ; bpp
    mov [0x5014], al
    mov al, 'v'
    call s2_serc

    ; ---------------- protected mode ----------------
    cli
    lgdt [gdt_desc]
    mov eax, cr0
    or  eax, 1                      ; PE
    mov cr0, eax
    jmp 0x08:pm_entry

vbe_error:
    mov al, 'V'
    call s2_serc
    mov si, s2_vbeerr
    call bios_print
.halt:  hlt
    jmp .halt
bad_kernel:
    mov al, 'B'
    call s2_serc
    mov si, s2_badkern
    call bios_print
.halt:  hlt
    jmp .halt
disk_error:
    mov al, 'D'
    call s2_serc
    mov si, s2_diskerr
    call bios_print
.halt:  hlt
    jmp .halt

bios_print:
    lodsb
    test al, al
    jz  .done
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    jmp bios_print
.done:
    ret

; --- polled serial (COM1 115200 8N1) for milestone markers ---
s2_ser_init:
    mov dx, 0x3F9
    mov al, 0
    out dx, al
    mov dx, 0x3FB
    mov al, 0x80
    out dx, al
    mov dx, 0x3F8
    mov al, 1
    out dx, al
    mov dx, 0x3F9
    mov al, 0
    out dx, al
    mov dx, 0x3FB
    mov al, 3
    out dx, al
    ret

; AL = char
s2_serc:
    push ax
    mov dx, 0x3FD
.w: in  al, dx
    test al, 0x20
    jz  .w
    pop ax
    mov dx, 0x3F8
    out dx, al
    ret

; SI = string
s2_sers:
    lodsb
    test al, al
    jz  .d
    call s2_serc
    jmp s2_sers
.d:
    ret

s2_hello   db "S2 ", 0
s2_on      db "s2-serial on", 10, 0
s2_e820    db "mem ", 0
s2_kern    db "krn ", 0
s2_vbe     db "vbe ", 0
s2_vbeerr  db "VBE-ERR", 0
s2_badkern db "BAD-KRN", 0
s2_diskerr db "DISK-ERR", 0

align 4
mode_best dw 0
kern_off  dd 0

align 8
gdt:
    dq 0
    dq 0x00CF9A000000FFFF           ; 0x08 32-bit code
    dq 0x00CF92000000FFFF           ; 0x10 32-bit data
    dq 0x00AF9A000000FFFF           ; 0x18 64-bit code
gdt_end:
gdt_desc:
    dw gdt_end - gdt - 1
    dd gdt

align 8
dap_kern:
    db 0x10, 0
    db 0, 0
    dw 0, 0x1000
    dq 0

; =============================================================================
BITS 32
; polled serial char, AL (32-bit)
pm_serc:
    push eax
    push edx
    mov dx, 0x3FD
.w: in  al, dx
    test al, 0x20
    jz  .w
    pop edx
    pop eax
    mov dx, 0x3F8
    out dx, al
    ret

pm_entry:
    mov al, 'P'
    call pm_serc
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax
    mov esp, 0x7C00

    ; copy kernel 0x10000 -> 0x100000
    mov esi, 0x10000
    mov edi, 0x100000
    mov ecx, [0x10004]
    mov ebx, ecx
    shr ecx, 2
    rep movsd
    and ebx, 3
    jz  .copied
    mov cl, bl
    rep movsb
.copied:
    mov al, 'c'
    call pm_serc

    ; ------- page tables: identity 0-4 GiB via 2 MiB pages -------
    ; PML4 0x90000 | PDPT 0x91000 | PD0 0x92000 .. PD3 0x95000
    ; (0x90000-0x99FFF: free conventional RAM above stage2, below EBDA)
    mov edi, 0x90000
    xor eax, eax
    mov ecx, 0x1800                 ; zero 0x90000..0x95FFF (6 KiB)
    rep stosd

    mov dword [0x90000], 0x91000 | 0x03
    mov dword [0x91000], 0x92000 | 0x03
    mov dword [0x91008], 0x93000 | 0x03
    mov dword [0x91010], 0x94000 | 0x03
    mov dword [0x91018], 0x95000 | 0x03

    mov edi, 0x92000
    mov eax, 0x83                   ; P|W|PS, phys 0
    mov ecx, 2048
.fill_pd:
    mov [edi], eax
    mov dword [edi + 4], 0
    add eax, 0x200000
    add edi, 8
    loop .fill_pd
    mov al, 't'
    call pm_serc

    ; ---------------- long mode ----------------
    mov eax, cr4
    or  eax, 1 << 5                 ; PAE
    mov cr4, eax
    mov eax, 0x90000
    mov cr3, eax
    mov ecx, 0xC0000080             ; EFER
    rdmsr
    or  eax, 1 << 8                 ; LME
    wrmsr
    mov eax, cr0
    or  eax, 0x80000000             ; PG
    mov cr0, eax
    mov al, 'G'
    call pm_serc

    jmp 0x18:lm_entry

; =============================================================================
BITS 64
lm_entry:
    ; serial 'L' (poll THRE)
    mov dx, 0x3FD
.wl: in  al, dx
    test al, 0x20
    jz  .wl
    mov al, 'L'
    mov dx, 0x3F8
    out dx, al
    mov eax, [0x5020]               ; kernel size
    add eax, 0x100000 + 0xFFFF      ; +64 KiB headroom
    and eax, ~15
    mov rsp, rax
    mov rbp, 0
    mov rdi, 0x5000                 ; BOOTINFO

    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax

    mov rax, 0x100010               ; kernel entry (past 16-byte header)
    jmp rax

stage2_pad:
    times (32*512) - (stage2_pad - stage2_start) db 0xCC
