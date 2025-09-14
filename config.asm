; config.asm
; load_config(filename_ptr) -> RAX = 0 (ok) or -1 (error)
; Lee config.ini y guarda:
;   cfg_char (bytes UTF-8, hasta 4 bytes)  + cfg_char_len (byte)
;   cfg_color_barra (dword)
;   cfg_color_fondo (dword)

%define BUFFER_SIZE 512    ;cantidad adecuada que leemos
%define MAX_CHAR_BYTES 4   ;4 bytes por caracter

section .data
; Variables de configuración (globales, accesibles desde draw.asm)
cfg_char:           times MAX_CHAR_BYTES db 0   ; almacenar 1..4 bytes del caracter
cfg_char_len:       db 0                        ;longitud
;codigos ANSI
cfg_color_barra:    dd 0
cfg_color_fondo:    dd 0

; Llaves en config.ini (sin ':')
key_caracter:       db "caracter_barra"
key_caracter_len    equ $-key_caracter    ;sirve para comparar longitudes
key_color_barra:    db "color_barra"
key_color_barra_len equ $-key_color_barra
key_color_fondo:    db "color_fondo"
key_color_fondo_len equ $-key_color_fondo

; Mensajes de error
err_open:           db "Error abriendo config.ini", 10
err_open_len        equ $-err_open
err_read:           db "Error leyendo config.ini", 10
err_read_len        equ $-err_read

section .bss
readbuf:            resb BUFFER_SIZE  ;al buffer bss lo llenamos con file_read

section .text
    global load_config
    extern file_open, file_read, file_close

; -------------------
; Entrada:
;   RDI = puntero filename (C-string)
; Salida:
;   RAX = 0  -> ok
;   RAX = -1 -> error
; Efecto:
;   Actualiza cfg_char, cfg_char_len, cfg_color_barra, cfg_color_fondo
; -------------------
load_config:
    ; Prologo: preservar registros callee-saved
    push rbp   ;por conveniencia rbp
    mov rbp, rsp
	;salvarlos
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; --- Abrir archivo (file_open espera filename en RDI) ---
    call file_open
    cmp rax, 0             ;si es menor a 0, brinca a .err_..
    js .err_no_open
    mov r12, rax          ; r12 = fd

    ; --- Leer archivo (una sola lectura, BUFFER_SIZE) ---
    mov rdi, r12	   ;rdi=fd
    lea rsi, [rel readbuf] ;rsi=buffer
    mov rdx, BUFFER_SIZE   ;rdx=size
    call file_read
    cmp rax, 0
    js .cleanup_and_err
    mov r13, rax          ; r13 = bytes leídos

    ; --- Inicializar puntero y contador para parsear ---
    lea rsi, [rel readbuf]     ;rsi = puntero de trabajo al buffer
    mov rcx, r13              ;rcx = bytes restantes
    ; limpiar valores configuracion por defecto
    lea rdi, [rel cfg_char]
    mov byte [rel cfg_char_len], 0
    mov dword [rel cfg_color_barra], 0
    mov dword [rel cfg_color_fondo], 0

.parse_line:
    ; Si no quedan bytes terminamos
    cmp rcx, 0
    je .done

    ; saltar nuevos lineas o espacios iniciales
.skip_blank:
    mov al, [rsi]
    cmp al, 10      ; '\n'
    je .skip_blank_advance
    cmp al, 13      ; '\r'
    je .skip_blank_advance
    cmp al, ' '     ; espacio (en inicio de línea)
    je .skip_blank_advance
    jmp .line_start
.skip_blank_advance:
    inc rsi
    dec rcx
    cmp rcx, 0
    jne .skip_blank
    jmp .done

.line_start:
    ; rbx = inicio de la llave (token antes de ':')
    mov rbx, rsi

.find_colon:
    cmp rcx, 0
    je .done
    mov al, [rsi]
    cmp al, ':'
    je .colon_found
    cmp al, 10    ; newline => línea inválida, saltarla
    je .skip_line
    inc rsi
    dec rcx
    jmp .find_colon

.colon_found:
    ; calcular token_len = rsi - rbx (excluye ':')
    mov rax, rsi
    sub rax, rbx        ; rax = token_len (posible con espacios)
    ; trim trailing spaces: si el último char antes de ':' es ' ' reduce len
    ; rdx = token_len, longitud sin espacios finales
    mov rdx, rax
    cmp rdx, 0
    je .process_key
    lea r8, [rsi - 1]   ; r8 = ultimo caracter antes de  ':'
.trim_trailing:
    mov bl, [r8]
    cmp bl, ' '
    jne .trim_done
    dec r8
    dec rdx
    cmp rdx, 0
    jne .trim_trailing
.trim_done:
    ; Ahora rbx = token start, rdx = trimmed token length
    ; Guardar el puntero de token en rsi_temp para comparar despues
    mov r9, rbx         ; r9 = token_start
    mov r10, rdx        ; r10 = token_len

.process_key:
    ; saltar ':' al valor
    inc rsi
    dec rcx

    ; Omitir espacios después de ':'
.skip_spaces_after_colon:
    cmp rcx, 0
    je .process_value
    mov al, [rsi]  ;rsi para apuntar a valor de inicio y saltar espacios
    cmp al, ' '
    jne .process_value
    inc rsi
    dec rcx
    jmp .skip_spaces_after_colon

.process_value:
    ; Ahora r9=token_start, r10=token_len, rsi apunta al valor inicial, rcx  bytes restantes
    ; Comparar token con cada llave conocida

    ; --- comparar con key_caracter ---
    mov rax, r10
    cmp rax, key_caracter_len
    jne .check_color_barra
    ; longitudes iguales -> comparar byte a byte
    mov rsi, r9
    lea rdi, [rel key_caracter]
    mov r11, rax         ; r11 = copia del len
    xor r8, r8
.compare_key1:
    mov al, [rsi]
    mov bl, [rdi]
    cmp al, bl
    jne .check_color_barra
    inc rsi
    inc rdi
    dec r11
    jnz .compare_key1
    
	;necesitamos el valor de rsi en process_value
   
    lea rsi, [r9 +  r10] ; r9 + r10 , posicion antes de : , pero rsi al estar en valor inicial, para mayor seguridad recalculamos r9+r10+1, omitiendo : y espacios
    lea rsi, [r9 + r10] ; puntos de ':' -> se mueve uno ':'
    inc rsi
    sub rcx, 0          ; rcx sin cambiar
    
.skip_spaces_for_char:
    cmp rcx, 0
    je .char_store_done
    mov al, [rsi]
    cmp al, ' '
    jne .char_collect_start
    inc rsi
    dec rcx
    jmp .skip_spaces_for_char

.char_collect_start:
    ;Recolecta hasta MAX_CHAR_BYTES o nueva linea
    mov rdx, 0           ; rdx = bytes recolectados
.collect_char_loop:
    cmp rcx, 0		 ;rcx bytes restantes del buffer
    je .char_store_done
    cmp rdx, MAX_CHAR_BYTES
    je .char_store_done
    mov al, [rsi]        ;rsi es el puntero 
    cmp al, 10      ; hay nueva linea o no
    je .char_store_done
    cmp al, 13
    je .char_store_done
    ; guarda byte en cfg_char + rdx
    lea rdi, [rel cfg_char]
    add rdi, rdx
    mov [rdi], al
    inc rsi
    dec rcx
    inc rdx
    jmp .collect_char_loop

.char_store_done:
    ; guarda largo
    mov rdi, rdx
    mov [rel cfg_char_len], dil  ;guarda el byte bajo
    jmp .after_key_handled

; --- comparar con key_color_barra ---
.check_color_barra:
    ; resetea rsi al puntero de inico del token (r9)
    mov rsi, r9
    mov rax, r10
    cmp rax, key_color_barra_len
    jne .check_color_fondo
    ; compara byte por byte
    lea rdi, [rel key_color_barra]
    mov r11, rax
.compare_key2:
    mov al, [rsi]
    mov bl, [rdi]
    cmp al, bl
    jne .check_color_fondo
    inc rsi
    inc rdi
    dec r11
    jnz .compare_key2
    ; coincide key_color_barra -> parse integra el valor
    ; Valor del punter: se calcula  r9 + r10 + 1 , para saltar espacios
    lea rsi, [r9 + r10]
    inc rsi
    
.skip_spaces_val2:
    cmp rcx, 0
    je .after_key_handled
    mov al, [rsi]
    cmp al, ' '
    jne .parse_int_barra
    inc rsi
    dec rcx
    jmp .skip_spaces_val2

.parse_int_barra:
    xor rax, rax    ; acomulador
.parse_int_barra_loop:
    cmp rcx, 0
    je .store_color_barra
    mov bl, [rsi]
    cmp bl, 10
    je .store_color_barra
    cmp bl, 13
    je .store_color_barra
    cmp bl, '0'
    jl .store_color_barra
    cmp bl, '9'
    jg .store_color_barra
    imul rax, rax, 10
    movzx rdx, bl
    sub rdx, '0'
    add rax, rdx
    inc rsi
    dec rcx
    jmp .parse_int_barra_loop
.store_color_barra:
    mov dword [rel cfg_color_barra], eax
    jmp .after_key_handled

; --- comparar con key_color_fondo ---
.check_color_fondo:
    mov rsi, r9
    mov rax, r10
    cmp rax, key_color_fondo_len
    jne .after_key_handled
    lea rdi, [rel key_color_fondo]
    mov r11, rax
.compare_key3:
    mov al, [rsi]
    mov bl, [rdi]
    cmp al, bl
    jne .after_key_handled
    inc rsi
    inc rdi
    dec r11
    jnz .compare_key3
    ; si coincide  key_color_fondo -> parse integra
    lea rsi, [r9 + r10]
    inc rsi
.skip_spaces_val3:
    cmp rcx, 0
    je .after_key_handled
    mov al, [rsi]
    cmp al, ' '
    jne .parse_int_fondo
    inc rsi
    dec rcx
    jmp .skip_spaces_val3

.parse_int_fondo:
    xor rax, rax
.parse_int_fondo_loop:
    cmp rcx, 0
    je .store_color_fondo
    mov bl, [rsi]
    cmp bl, 10
    je .store_color_fondo
    cmp bl, 13
    je .store_color_fondo
    cmp bl, '0'
    jl .store_color_fondo
    cmp bl, '9'
    jg .store_color_fondo
    imul rax, rax, 10
    movzx rdx, bl
    sub rdx, '0'
    add rax, rdx
    inc rsi
    dec rcx
    jmp .parse_int_fondo_loop
.store_color_fondo:
    mov dword [rel cfg_color_fondo], eax

.after_key_handled:
    ; saltar hasta fin de línea (si no estamos ya en '\n')
.skip_to_end_of_line:
    cmp rcx, 0
    je .parse_line
    mov al, [rsi]
    cmp al, 10
    je .advance_past_nl2
    inc rsi
    dec rcx
    jmp .skip_to_end_of_line

.advance_past_nl2:
    inc rsi
    dec rcx
    jmp .parse_line

.skip_line:
    ; salto por linea inválida (sin ':')
.skip_line_loop:
    cmp rcx, 0
    je .parse_line
    mov al, [rsi]
    inc rsi
    dec rcx
    cmp al, 10
    jne .skip_line_loop
    jmp .parse_line

.done:
    ; cerrar archivo y devolver éxito (0)
    mov rdi, r12
    call file_close
    mov rax, 0
    jmp .restore_and_ret

.cleanup_and_err:
    ; intentar cerrar fd si lo tenemos y devolver -1
    mov rax, -1
    mov rdi, r12
    call file_close
    jmp .restore_and_ret

.err_no_open:
    mov rax, -1

.restore_and_ret:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
