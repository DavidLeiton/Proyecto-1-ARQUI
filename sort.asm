; sort.asm  - Selection sort, seguro para names[] (bloques de 32 bytes) y quantities[] (dwords)
%define MAX_NAME_LEN    32
%define MAX_NAME_SHIFT   5   ; 2^5 = 32

section .bss
temp_name:    resb MAX_NAME_LEN

section .text
    global sort_inventory
    extern names, quantities

sort_inventory:
    ; Prologo - preservar callee-saved
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15
    push rbx

    mov r12, rdi        ; r12 = count
    cmp r12, 2
    jl .done            ; 0 o 1 elemento -> nada que ordenar

    ; bases
    lea r13, [rel names]      ; r13 = base names
    lea r14, [rel quantities] ; r14 = base quantities

    xor rbx, rbx        ; rbx = i = 0

.outer_i:
    mov rax, r12
    dec rax
    cmp rbx, rax
    jge .done      ; si i >= count-1, terminado

    ; min_index = i
    mov r15, rbx         ; r15 = min_index

    ; j = i+1
    mov rcx, rbx
    inc rcx              ; rcx = j

.find_min_loop:
    cmp rcx, r12
    jge .found_min

    ; addr_min = names + min_index*32 -> use rsi
    mov rax, r15
    shl rax, MAX_NAME_SHIFT
    lea rsi, [r13 + rax]    ; rsi = &names[min_index]

    ; addr_j = names + j*32 -> use rdi
    mov rax, rcx
    shl rax, MAX_NAME_SHIFT
    lea rdi, [r13 + rax]    ; rdi = &names[j]

    ; compare strings rsi vs rdi, limit MAX_NAME_LEN
    mov r8, MAX_NAME_LEN
.compare_chars:
    mov al, [rsi]
    mov dl, [rdi]
    cmp al, dl
    jb .j_not_smaller      ; if names[j] > names[min] -> update min
    ja .update_min        ; if names[j] < names[min] -> keep min
    ; equal char:
    test al, al
    jz .chars_equal   ; both terminated -> equal
    inc rsi
    inc rdi
    dec r8
    jnz .compare_chars
    jmp .chars_equal

.update_min:
    ; j < min -> set min_index = j
    mov r15, rcx
    jmp .next_j

.j_not_smaller:
    ; j > min -> do nothing
    jmp .next_j
.chars_equal:
.next_j:
    inc rcx
    jmp .find_min_loop

.found_min:
    ; if min_index != i -> swap names and quantities
    cmp r15, rbx
    je .no_swap

    ; --- swap names (3 copies) ---
    ; src_i = names + i*32  -> rsi
    mov rax, rbx
    shl rax, MAX_NAME_SHIFT
    lea rsi, [r13 + rax]
    lea rdi, [rel temp_name]
    mov rcx, MAX_NAME_LEN
    rep movsb
    ; src_min = names + min_index*32 -> rdi
    mov rax, r15
    shl rax, MAX_NAME_SHIFT
    lea rsi, [r13 + rax]
    mov rax, rbx
    shl rax, MAX_NAME_SHIFT
    lea rdi, [r13 + rax]
    mov rcx, MAX_NAME_LEN
    rep movsb

    ; copy names[i] -> temp_name
    lea rsi, [rel temp_name]
    mov rax, r15
    shl rax, MAX_NAME_SHIFT
    lea rdi, [r13 + rax]
    mov rcx, MAX_NAME_LEN
    rep movsb

    ;--swap quantities
    mov rax, rbx
    shl rax, 2
    mov ecx, [r14 + rax]

    mov rdx, r15
    shl rdx, 2
    mov edx, [r14 + rdx]

    mov [r14 + rax], edx
    mov rax, r15
    shl rax, 2
    mov [r14 + rax], ecx

.no_swap:
    inc rbx
    jmp .outer_i

.done:
    mov rax, r12   ; devolver count en rax por conveniencia

    ; epilogo - restaurar
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
