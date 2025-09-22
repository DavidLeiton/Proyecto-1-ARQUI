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
space_char:     db " ", 0   ;espacio separador
      

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
    je .name_len_done ;si recorre maximo termina
    mov al, [rsi]  ;lee byte actual
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
    lea rdi, [rel escbuf]       ; r8 = escbuf inicia
    mov r8, rdi                ; rdi = ecribe puntero en escbuf (buffer temporal)

    ; ESC '['
    mov byte [rdi], 27   ;se escribe Esc y [
    inc rdi
    mov byte [rdi], '['
    inc rdi

    ; escribir color_barra (integer -> ascii) en escbuf
    mov eax, dword [rel cfg_color_barra]
    call .uint_to_ascii        ; entrada: rax=value, rdi=dest; salida: rdi=dest_after, rdx=len
    ; rdi ya avanzado, rdx = digits len

    ; escribir ';'
    mov byte [rdi], ';'
    inc rdi

    ; escribir color_fondo
    mov eax, dword [rel cfg_color_fondo]   ; es leido
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
    mov rcx, r12                 ;rcx indice
    shl rcx, 2                   ;rcx = i*4
    lea rbx, [rel quantities]    ;base del array
    add rcx, rbx                 ;rcx = quantities[i]
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

    ;imprimir espacio separador
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel space_char]   
    mov rdx, 1         
    syscall


    ; === IMPRIMIR VALOR NUMÉRICO ===
    ; Recalcular dirección de la cantidad actual (índice todavía en R12)
    mov rax, r12               ; RAX = índice actual
    shl rax, 2                 ; RAX = i * 4
    lea rbx, [rel quantities]  ; RBX = base del array
    add rbx, rax               ; RBX = &quantities[i]
    mov eax, dword [rbx]       ; EAX = cantidad
    
    ; Convertir número a ASCII
    lea rdi, [rel numbuf]      ; Buffer temporal
    call .uint_to_ascii        ; RAX contendrá la longitud
    
    ; Imprimir el número (RAX = longitud retornada por uint_to_ascii)
    mov rdx, rax               ; Longitud del número
    mov rax, 1                 ; sys_write
    mov rdi, 1                 ; stdout
    lea rsi, [rel numbuf]      ; Número en ASCII
    syscall

    ; ---------- Imprimir reset ESC[0m ----------
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel reset_seq]   ;secuiencia de reset
    mov rdx, reset_len         ;len 4 bytes
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

    push r14   ;antes r15 rdi antes
    push rbx
    push rcx
    push rsi

    mov rbx, rdi         ;rbx puntero original
    lea rsi, [rel numbuf] ;rsi buffer temporal
    add rsi, 15     ;al final de buffer
    mov byte [rsi], 0
    mov rcx, 10    ;divisor base 10
    
    ;caso especial cero
    test rax, rax
    jnz .convert_loop
    mov byte [rsi-1], '0'
    dec rsi
    mov rdx, 1
    jmp .copy_digits

.convert_loop:
    xor rdx, rdx   ;limpia rdx
    div rcx        ;rax cociente y rdx residuo
    add dl, '0'
    dec rsi        ;retrocede en buffer
    mov [rsi], dl   ;almacena digito
    test rax, rax
    jnz .convert_loop

    ;calcular longitud

    lea rdx, [rel numbuf+16]  ;fin del buffer
    sub rdx, rsi               ;longitud en bytes
.copy_digits:
    mov rcx, rdx           ;rcx longitud
    mov rdi, rbx           ;rdi destino original
    rep movsb               ; se copian digitos en buffer temporal

    ;retornar longitud

    mov rax, rdx

    mov rdi, rbx         ;rdi destino original
    add rdi, rdx          ;dest+longitud
   ;devolvemos
    pop r14
    pop rsi
    pop rcx
    pop rbx
    ret
