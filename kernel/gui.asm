
 gui_draw_windows:
     push rbx
     push r12
-    mov r12d, 1                 ; z from 1..win_ztop
-.zl:
-    mov eax, [win_ztop]
-    cmp r12d, eax
-    ja .done
-    xor ebx, ebx
-.wl:
+    push r13
+    push r14
+    push r15
+    sub rsp, 16
+
+    ; Local state:
+    ; [rsp]   = last rendered Z
+    ; [rsp+4] = best candidate Z
+    ; [rsp+8] = best candidate slot
+    mov dword [rsp], 0
+    xor r13d, r13d              ; at most eight windows
+
+.pass:
+    cmp r13d, 8
+    jae .done
+
+    mov dword [rsp + 4], 0FFFFFFFFh
+    mov dword [rsp + 8], -1
+    xor ebx, ebx
+
+.scan:
     cmp ebx, 8
-    jae .wn
+    jae .select
+
     mov eax, ebx
     imul eax, eax, 48
     lea rdi, [windows]
     add rdi, rax
+
     cmp byte [rdi + W_VIS], 0
-    je .next
-    cmp [rdi + W_Z], r12d
-    jne .next
-    call gui_draw_win
-.next:
+    je .next
+
+    ; Find the smallest visible Z greater than the last one.
+    mov eax, [rdi + W_Z]
+    cmp eax, [rsp]
+    jbe .next
+    cmp eax, [rsp + 4]
+    jae .next
+
+    mov [rsp + 4], eax
+    mov [rsp + 8], ebx
+
+.next:
     inc ebx
-    jmp .wl
-.wn:
-    inc r12d
-    jmp .zl
+    jmp .scan
+
+.select:
+    cmp dword [rsp + 8], -1
+    je .done
+
+    mov eax, [rsp + 4]
+    mov [rsp], eax
+
+    mov eax, [rsp + 8]
+    imul eax, eax, 48
+    lea rdi, [windows]
+    add rdi, rax
+    call gui_draw_win
+
+    inc r13d
+    jmp .pass
+
 .done:
+    add rsp, 16
+    pop r15
+    pop r14
+    pop r13
     pop r12
     pop rbx
     ret
