; sort.asm  - Section sort, seguro para names[] (bloques de 32 bytes) y quantities[] (dwords)
;algoritmo estable para arrays pequeños

%define MAX_NAME_LEN    32
%define MAX_NAME_SHIFT   5   ; 2^5 = 32

section .bss
;buffer temporal para swapping de nombres
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
    cmp r12, 2          ;ve si hay menos de 2
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
    inc rcx              ; rcx = i + 1

.find_min_loop:
    cmp rcx, r12   ; verifica si j contador
    jge .found_min

    ; addr_min = names + min_index*32 -> use rsi
    mov rax, r15
    shl rax, MAX_NAME_SHIFT   ;rax, min_index *32
    lea rsi, [r13 + rax]    ; rsi = &names[min_index]

    ; addr_j = names + j*32 -> use rdi
    mov rax, rcx    ;rax j
    shl rax, MAX_NAME_SHIFT ;rax j*32
    lea rdi, [r13 + rax]    ; rdi = &names[j]

    ; compare strings rsi vs rdi, limit MAX_NAME_LEN
    mov r8, MAX_NAME_LEN; contador bytes
.compare_chars:
    mov al, [rsi]   ;al es names[min_index]
    mov dl, [rdi]   ;dl names[j]
    cmp al, dl
    jb .j_not_smaller      ; if names[j] > names[min] -> no actualiza
    ja .update_min        ; if names[j] < names[min] -> actualiza minimo
    ; equal char:
    test al, al
    jz .chars_equal   ; ambos terminan si son iguales
    inc rsi
    inc rdi
    dec r8
    jnz .compare_chars ;continua si hay bytes por comparar
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
    ; if min_index != i -> swap de names y quantities
    cmp r15, rbx
    je .no_swap

    ; --- swap names (3 copies) ---
    ; src_i = names + i*32  -> rsi

    ;copiar names[i] a temp_name
    mov rax, rbx               ;rax = i
    shl rax, MAX_NAME_SHIFT   ;rax = i * 32
    lea rsi, [r13 + rax]      ;rsi = &names[i]
    lea rdi, [rel temp_name]  ;rdi = temp_name
    mov rcx, MAX_NAME_LEN
    rep movsb                  ;copia bloque de memoria

    ; src_min = names + min_index*32 -> rdi
    mov rax, r15               ;rax = min_index
    shl rax, MAX_NAME_SHIFT    ;rax = min_index*32
    lea rsi, [r13 + rax]       ;rsi = &names[min_index]
    mov rax, rbx               ;rax = i
    shl rax, MAX_NAME_SHIFT    ;rax = i*32  
    lea rdi, [r13 + rax]    ;rdi = &names[i]
    mov rcx, MAX_NAME_LEN
    rep movsb

    ; copy names[i] -> temp_name
    lea rsi, [rel temp_name]      ;rsi = temp_name
    mov rax, r15                  ;rax = min_index
    shl rax, MAX_NAME_SHIFT       ;rax = min_index  *32
    lea rdi, [r13 + rax]          ;rdi = &names[min_index]
    mov rcx, MAX_NAME_LEN
    rep movsb

    ;--swap quantities
    mov rax, rbx       ;rax = i
    shl rax, 2         ;i*4
    mov ecx, [r14 + rax] ;ecx =quantities(i)

    mov rdx, r15      ;rdx = min_index
    shl rdx, 2        ;min * 4
    mov edx, [r14 + rdx] ;quantities[i]

    mov [r14 + rax], edx  ;quantities[i]= quantities[min_index]
    mov rax, r15           ;rax min_index
    shl rax, 2             ;min_index * 4
    mov [r14 + rax], ecx   ;quantities[min_index] = quantities[i]

.no_swap:
    inc rbx   ;i++
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
