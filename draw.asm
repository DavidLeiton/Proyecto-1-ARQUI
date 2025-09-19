; draw.asm
; draw_graph(count)
; Dibuja cada registro: "nombre: <barra de caracteres en color>\n"
; Usa:
;   names[] (strings, MAX_NAME_LEN bytes cada una)
;   quantities[] (dd)
;   cfg_char, cfg_char_len, cfg_color_barra, cfg_color_fondo  (de config.asm)

%define MAX_NAME_LEN 32   ;cada nombre con 32 bytes
%define MAX_NAME_SHIFT 5   ; 2^5 = 32
%define MAX_ITEMS 32		;max que se guarda

section .data
sep:            db ": ", 0     ;cadena : seguida de 0
sep_len         equ $-sep      ;calcula longitud sin terminador
newline:        db 10		;contiene 0x0A
newline_len     equ $-newline    ;para escribrir lineas al final de barras
reset_seq:      db 27, '[', '0', 'm'     ; ESC[0m, secuencia ANSI
reset_len       equ $-reset_seq      ;Sirve para restaurar colores
default_char:   db '*'			;si no se usa barra
default_char_len equ 1			;longitud fija 1 B
      

section .bss
escbuf:         resb 32    ; buffer para construir secuencia ESC[...]m
numbuf:         resb 16    ; buffer temporal para conversión uint->ascii

section .text
    global draw_graph

    extern names, quantities ;vienen de parse
    extern cfg_char, cfg_char_len, cfg_color_barra, cfg_color_fondo

; ----------------------------
; Entrada:
;   RDI = count (número de items)
; Salida:
;   RAX = 0 (convención, no usado)
; ----------------
draw_graph:
    ; --- prologo: preservar callee-saved que usaremos ---
    push rbp    ;usar para depuracion
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r15, rdi        ; r15 = count
    cmp r15, 0		;si r15<=0 no dibuja
    jle .done_draw      ; nada que dibujar

    xor r12, r12        ; r12 = index i = 0

.loop_items:
    cmp r12, r15    ;si i >= count, termina
    jge .done_draw

    ;  Calcular puntero al nombre: name_ptr = names + i*MAX_NAME_LEN 
    mov rax, r12
    shl rax, MAX_NAME_SHIFT    ; rax = i * MAX_NAME_LEN
    lea rbx, [rel names]       ; rbx = base de direcciones de names
    add rax, rbx               ; rax = &names[i]
    mov r13, rax               ; r13 = name_ptr (guardar)

    ; Calcular longitud del nombre (strlen hasta 0 o MAX_NAME_LEN)
    mov rsi, r13               ; rsi = puntero que escanea
    mov rcx, MAX_NAME_LEN
    xor rdx, rdx               ; rdx = name_len contador
	; Aqui vamos a iteramos bytes desde name_ptr hasta \0 o Max name len
.find_name_len:
    cmp rcx, 0
    je .name_len_done
    mov al, [rsi]
    cmp al, 0
    je .name_len_done
    inc rsi
    inc rdx
    dec rcx
    jnz .find_name_len
.name_len_done:
    ;evitar sobre escribir rdx ...
    mov r14, rdx
     
    ; -- Imprimir name ---
    mov rax, 1                 ; sys_write
    mov rdi, 1                 ; stdout, fb
    mov rsi, r13               ; puntero a name
    mov rdx, r14               ; len, antes rdx
    syscall

    ; - Imprimir separador ": " 
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel sep]
    mov rdx, sep_len
    syscall

    ; Aqui vamos a construir y escribir secuencia ANSI de color: ESC[<fg>;<bg>m] 
    lea r8, [rel escbuf]       ; r8 = escbuf inicia
    mov rdi, r8                ; rdi = ecribe puntero en escbuf (buffer temporal)

    ; ESC '['
    mov byte [rdi], 27   ;se escribe Esc y [
    inc rdi
    mov byte [rdi], '['
    inc rdi

    ; escribir color_barra (integer -> ascii) en escbuf
    mov eax, dword [rel cfg_color_barra]
    ;mov rax, rax               ; valor en rax
    call .uint_to_ascii        ; entrada: rax=value, rdi=dest; salida: rdi=dest_after, rdx=len
    ; rdi ya avanzado, rdx = digits len

    ; escribir ';'
    mov byte [rdi], ';'
    inc rdi

    ; escribir color_fondo
    mov eax, dword [rel cfg_color_fondo]   ; es leido
    ;mov rax, rax
    call .uint_to_ascii

    ; escribir 'm'
    mov byte [rdi], 'm'
    inc rdi

    ; calcular longitud y hacer sys_write
    mov rsi, r8                ; puntero de inicio
    mov rdx, rdi
    sub rdx, r8                ; rdx = length
    mov rax, 1
    mov rdi, 1
    syscall

    ; ---------- Obtener cantidad y preparar carácter ----------
    ; quantities address = quantities + i*4
	;quantities es array de dd
    mov rcx, r12
    shl rcx, 2
    lea rbx, [rel quantities]
    add rcx, rbx
    mov eax, dword [rcx]      ; eax = quantity
    cmp eax, 0
    jle .after_bar_print      ; si cantidad <=0, saltar

    ; establecer puntero al carácter y longitud
    movzx r9, byte [rel cfg_char_len]   ; r9 = cfg_char_len (zero-extended)
    cmp r9, 0
    jne .use_cfg_char
    lea rsi, [rel default_char]   ;rsi apunta a default_char
    mov r10d, default_char_len    ;r10 guarda len
    jmp .char_ready
.use_cfg_char:
    lea rsi, [rel cfg_char]
   ; mov r10d, dword [rel cfg_char_len]  ; r10 = char_len (32-bit -> zero-extended)
    movzx r10, byte [rel cfg_char_len]

.char_ready:
    ; ahora rsi = pointer al carácter a imprimir (1..4 bytes), r10 = longitud (dword)
    mov r14, rax            ; r14 = loop counter (quantity)

.print_char_loop:
    cmp r14, 0
    je .after_bar_print
    mov rax, 1
    mov rdi, 1
    mov rdx, r10           ; longitud de caracter 
    syscall                ; write cfg_char (rsi listo para los puntos de  cfg_char)
    dec r14
    jmp .print_char_loop

.after_bar_print:
    ; ---------- Imprimir reset ESC[0m ----------
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel reset_seq]
    mov rdx, reset_len
    syscall

    ; ---------- Imprimir newline ----------
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel newline]
    mov rdx, newline_len
    syscall

    ; incrementar index y seguir
    inc r12
    jmp .loop_items

.done_draw:
    mov rax, 0

    ; epilogo: restaurar registros
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret


; uint_to_ascii: convierte rax (unsigned) -> ascii decimal
; Entrada:
;   rax = valor (>=0)
;   rdi = destino (puntero donde escribir dígitos en orden)
; Salidas:
;   rdi = puntero avanzado (apunta a byte después del último digit escrito)
;   rdx = número de dígitos escritos
; Clobbers: rbx, rcx, rsi, r14

.uint_to_ascii:

    push r15   ; rdi antes
    push rbx
    push rcx
    push rsi

    ;lea rdi, [rel numbuf]
    mov rbx, rdi
    
   ; mov rsi, numbuf
   ; mov rcx, rdx
   ; rep movsb  ;copiar

    
    cmp rax, 0
    jne .itoa_nonzero
    ; escribir '0'
    mov byte [rbx], '0'
    lea rdi, [rbx + 1]
    ;inc rdi
    mov rdx, 1
   ; ret
    jmp .copy_final

.itoa_nonzero:
    lea rsi, [rel numbuf]   ; rsi = buffer temporal de inicio
    xor rcx, rcx            ; rcx = digito contador

.itoa_loop:
    xor rdx, rdx            ; limpia rdx por  div
    mov r15, 10
    div r15                 ; rax = quot, rdx = rem
    add dl, '0'             ; convertir  rem -> ascii digito en  dl
    mov [rsi], dl
    inc rsi
    inc rcx
    test rax, rax;cmp rax, 0
    jne .itoa_loop

    ; rcx = digit count, rsi = ptr despues del ultimo digito guardadoc(digitos guardados reservados)
    mov rdx, rcx            ; guarda contador en r14
    dec rsi                 ; punto al ultimo digito 

    mov rdi, rbx            ; puntero de destino en rbx

.rev_copy_loop:
    mov al, [rsi]
    mov [rsi], al ; antes rbx
    dec rsi
    inc rdi
    dec rcx    ;r14
    jnz .rev_copy_loop
    

.copy_final:
    pop rsi
    pop rcx
    pop rbx
    pop r15
    ret
    ;push rdi
    ;lea rsi, [rel numbuf]
    ;mov rcx, rdx
    ;rep movsb
    ; rbx ahora destino
    ;mov rdx, rcx            ; rdx = contador
    ;mov rdi, rbx            ; actualiza rdi a destino_despues
    ;pop rdi
    ;add rdi, rdx
    ;ret



