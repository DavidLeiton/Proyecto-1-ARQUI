; sort.asm
; sort_inventory(count)
; Ordena alfabeticamente names[] (tamaño fijo MAX_NAME_LEN) y hace swap paralelo de quantities[]
; Bubble Sort por simplicidad.
;Mismas variables que en parse
%define MAX_ITEMS 32
%define MAX_NAME_LEN 32
%define MAX_NAME_SHIFT 5    ; 2^5 = 32

section .bss
temp_name:    resb MAX_NAME_LEN    ; buffer temporal para hacer swap de nombres

section .text
    global sort_inventory  ;nueva funcion
    extern names, quantities      ; definidos en parse.asm

; -----------------------------------
; Entrada:
;   RDI = count (número de items)
; Salida:
;   RAX = count (devuelve el número de items)
;----------------------------------
sort_inventory:
    ; --- prologo: preservar registros callee-saved que usaremos ---
    push rbp
    mov rbp, rsp
	;salvamos registros que vamos a usar
    push rbx  
    push r12
    push r13
    push r14
    push r15

    mov r15, rdi        ; r15 = n (count)
    ; Si n <= 1 no hay nada que ordenar
    cmp r15, 1          ; si hay 0 o 1 no ordena
    jle .done_sort
	;estructura bubble sort
    xor r12, r12        ; r12 = i (outer index) = 0

.outer_loop:
    ; inner_limit = n - 1 - i
    mov r13, r15
    dec r13              ; r13 = n-1
    sub r13, r12         ; r13 = n-1-i
    cmp r13, 0
    jle .done_sort       ; si ya no hay pares que comparar, terminamos

    xor r11, r11         ; r11 = j = 0 (inner index)

.inner_loop:;recorre los j 0...
    ; --- calcular addr_j = names + j * MAX_NAME_LEN ---
    mov rax, r11
    shl rax, MAX_NAME_SHIFT    ; rax = j * MAX_NAME_LEN
    lea rbx, [rel names]	
    add rax, rbx               ; rax = &names[j] 

    ; addr_j1 = addr_j + MAX_NAME_LEN
    lea rdx, [rax + MAX_NAME_LEN]  ; rdx = &names[j+1]

    ; --- comparar strings names[j] y names[j+1] byte a byte ---
    mov rcx, MAX_NAME_LEN   ;limte de longitud
	;punteros a comparar
    mov rsi, rax    ; p1
    mov rdi, rdx    ; p2

.compare_loop:
    mov bl, [rsi]	;lee byte de cada string
    mov al, [rdi]
    cmp bl, al		;iguales, next
    je .cmp_equal_char
    ; uso comparación UNSIGNED: si bl > al entonces names[j] > names[j+1] -> swap
    ja .do_swap
    ; bl < al -> no swap
    jmp .no_swap

.cmp_equal_char:
    cmp bl, 0        ; si llegamos a '\0' y son iguales => strings iguales
    je .no_swap
    inc rsi
    inc rdi
    dec rcx
    jnz .compare_loop
    ; si agotamos MAX_NAME_LEN y todavía todo igual -> no swap
    jmp .no_swap

.do_swap:
    ; ---------- swap de nombres (3 copias: j -> temp, j+1 -> j, temp -> j+1) ----------
    ; copiar names[j] -> temp_name
    mov rcx, MAX_NAME_LEN
    mov rsi, rax        ; src = addr_j
    lea rdi, [rel temp_name] ; dst = temp_name
.copy_to_temp:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz .copy_to_temp

    ; copiar names[j+1] -> names[j]
    mov rcx, MAX_NAME_LEN
    mov rsi, rdx        ; src = addr_j1
    mov rdi, rax        ; dst = addr_j
.copy_j1_to_j:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz .copy_j1_to_j

    ; copiar temp_name -> names[j+1]
    mov rcx, MAX_NAME_LEN
    lea rsi, [rel temp_name]
    mov rdi, rdx
.copy_temp_to_j1:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz .copy_temp_to_j1

    ; ---------- swap de quantities (4 bytes cada) ----------
    ; calcular addr_q = quantities + j*4
    mov rcx, r11
    shl rcx, 2           ; rcx = j * 4
    lea rbx, [rel quantities]
    add rcx, rbx         ; rcx = &quantities[j]
    mov eax, dword [rcx] ; eax = qj
    mov edx, dword [rcx + 4] ; edx = qj1
    mov dword [rcx], edx
    mov dword [rcx + 4], eax ;intercambio 

    ; finished swap -> continue
    jmp .after_compare

.no_swap:
    ; no swap, continua
.after_compare:
    ; incrementar j
    inc r11
    ; si j >= inner_limit entonces salir inner loop
    cmp r11, r13
    jl .inner_loop

    ; incrementar i (outer index)
    inc r12
    jmp .outer_loop  ;volvemos al outer

.done_sort:
    ; devolver count en rax (conveniencia)
    mov rax, r15

    ; epilogo: restaurar registros
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
