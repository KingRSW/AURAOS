; =============================================================================
; AURA-OS v2 — kernel/bss.inc
; ALL kernel .bss variables in one place (included from main.asm at the end,
; after all code/data, so .bss addresses land past the file image).
; Included between bss_start: / bss_end: labels.
; =============================================================================

; ---- GDT (gdt_idt.asm) ----
alignb 8
gdt_k:          resq 3
gdt_k_desc:     resw 1
                resq 1

; ---- PIT (pic_pit.asm) ----
pit_ticks:      resd 1

; ---- keyboard (kbd.asm) ----
kbd_buf:        resb 128
kbd_head:       resb 1
kbd_tail:       resb 1
kbd_shift:      resb 1
kbd_ext:        resb 1

; ---- mouse (mouse.asm) ----
mouse_x:        resd 1
mouse_y:        resd 1
mouse_b:        resb 1
mouse_cycle:    resb 1
mouse_raw:      resb 3

; ---- PMM (mem.asm) ----
alignb 8
pmm_bitmap:     resb 131072
pmm_free_pages: resd 1

; ---- framebuffer (gfx.asm) ----
fb_addr:        resq 1
fb_pitch:       resd 1
fb_width:       resd 1
fb_height:      resd 1
fb_bpp:         resd 1
aurora_buf:     resq 1
bb_addr:        resq 1

; ---- RTC (rtc.asm) ----
rtc_h:          resb 1
rtc_m:          resb 1
rtc_s:          resb 1

; ---- GUI state ----
dirty:          resb 1
prev_b:         resb 1                   ; previous left-button state
clk_last:       resd 1                   ; last processed clock tick-second
sin_tab:        resw 1024                ; aurora sine table (-127..127)

; ---- window manager ----
windows:        resb 8*48
win_ztop:       resd 1
drag_win:       resd 1
drag_dx:        resd 1
drag_dy:        resd 1

; ---- terminal app ----
term_buf:       resb 24*96
term_line:      resb 96
term_len:       resd 1
term_lines:     resd 1
term_num:       resb 32                  ; scratch for numeric reply lines

; ---- editor app ----
edit_buf:       resb 4096
edit_len:       resd 1
