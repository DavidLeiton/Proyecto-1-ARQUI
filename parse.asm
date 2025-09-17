; parse.asm
; load_inventory(filename_ptr) -> RAX = count (o -1 en error)
;  abre file_open, file_read, file_close en io.asm

%define MAX_ITEMS 32 ;maximas entradas a guardar
%define MAX_NAME_LEN 32        ; potencia de 2 (32 = 2^5) para multiplicar con shift
%define MAX_NAME_SHIFT 5       ; log2(MAX_NAME_LEN)
%define BUFFER_SIZE 4096

section .data
; arrays
names:       times MAX_ITEMS * MAX_NAME_LEN db 0 ;i empieza en names + i*Max_name_len
quantities:  times MAX_ITEMS dd 0 ;array 4 B c/u, quantities[i] guarda int 32b
item_count:  dd 0;conteo

; buffer para lectura
readbuf:     times BUFFER_SIZE db 0; leemos archivo

section .text
    global load_inventory ;para que main la llame
    global names
    global quantities
    global item_count
    extern file_open, file_read, file_close ;para io

; -------------------------------
; RDI = puntero a  (C-string)
; devueve RAX = count (0..MAX_ITEMS) o -1 si es error
; -----------------------------------
load_inventory:
    ; guardar callee-saved que usaremos
    push rbp 
    mov rbp, rsp ;establecen una pila
    push rbx
    push r12
    push r13
    push r14
    push r15; el push para salvarlos, se deben restaurar

	;limpiar rsi y rdx
    mov rsi, 0 ;O_RONLY
    mov rdx, 0

    ; abrir archivo (file_open espera filename en rdi)rdi tiene el puntero
    call file_open
    cmp rax, 0 ;si rax negativo (error) se brinca a js
    js .err_return        ; error (rax < 0)
    mov r12, rax          ; r12 = fd

    ; leer todo (una sola vez)
    mov rdi, r12          ;rdi = fd(r12)
    lea rsi, [rel readbuf] ;rsi puntero al buffer
    mov rdx, BUFFER_SIZE   ;tamaño 
    call file_read 
    cmp rax, 0 ;si rax<0, salta al js
    js .cleanup_and_err
    mov r13, rax          ; r13 = bytes leídos

    
    lea rsi, [rel readbuf] ;puntero de recorrido por el buffer
    mov rcx, r13           ;contador bytes restantes
    xor r15, r15          ; index = 0 (inicio), para names/quantities

.parse_loop:		;bucle, si no hay bytes (rcx==0) terminamos
    cmp rcx, 0
    je .done_parse

    ; saltar caracteres iniciales newline/carriage returns
.skip_leading:
    cmp rcx, 0 
    je .done_parse
    mov al, [rsi]
    cmp al, 10 ;salto de lineas iniciales en 10 o 13 para evitar lineas vacias
    je .advance_char1
    cmp al, 13
    je .advance_char1 
    jmp .set_start
.advance_char1:  ; incrementa rsi y decrementa rcx hasta encontrar caracter valido o quedartse sin bytes
    inc rsi
    dec rcx
    cmp rcx, 0
    jne .skip_leading
    jmp .done_parse

.set_start:
    mov rbx, rsi          ; rbx = product_start(puntero al incio de product)
    mov al, [rsi]
    cmp al, ':'
    je .skip_line
    cmp al, 0
    je .done_parse
    ;si no seguimos buscando
    jmp .find_colon     

; buscar ':' que separa producto de cantidad
.find_colon:
    cmp rcx, 0
    je .done_parse
    mov al, [rsi]
    cmp al, 10            ; si llega a fin de linea sin ':', salta esa linea
    je .skip_line
    cmp al, 13
    je .skip_line
    cmp al, ':' 	;verificar si esta :
    je .colon_found
    inc rsi
    dec rcx
    jmp .find_colon

;procesar producto si ya encontro :

.colon_found:
    ; longitud producto = rsi - rbx
    mov rax, rsi
    sub rax, rbx          ; rax = product_len
    ; limitar a MAX_NAME_LEN - 1 (dejamos 1 byte para '\0')
    cmp rax, MAX_NAME_LEN - 1
    jle .calc_dest
    mov rax, MAX_NAME_LEN - 1

.calc_dest:
    ; calcular dir destino: names + index*MAX_NAME_LEN
    mov rdx, r15		;index
    shl rdx, MAX_NAME_SHIFT    ; rdx = index * MAX_NAME_LEN(por 32, si Max..=5)
    lea rdi, [rel names]
    add rdi, rdx               ; rdi = apunta al incio de espacio reservado

    ; copiar product_len bytes desde rbx a rdi ( r8,r9 temporales)
    mov r8, rbx 		;se copia byte a byte de rbx a rdi(dest)
    mov r9, rax                ; r9 = len (veces)
.copy_name_loop:  		;pone 0 terminador al final del nombre
    cmp r9, 0
    je .term_name
    mov al, [r8]
    mov [rdi], al
    inc r8
    inc rdi
    dec r9
    jmp .copy_name_loop
.term_name:
    mov byte [rdi], 0          ; null-terminate

    ; saltar ':' y ajustar contador, para pasar a parte numerica
    inc rsi
    dec rcx

    ; omitir espacios entre ':' y número (si los hay)
.skip_spaces: 
    cmp rcx, 0
    je .parse_number
    mov al, [rsi]
    cmp al, ' '
    jne .parse_number
    inc rsi
    dec rcx
    jmp .skip_spaces

.parse_number:
    xor rax, rax               ; rax = 0 acumula el numero, para convertir secuancia ASCII a entero
.parse_digits:
    cmp rcx, 0
    je .store_number
    mov bl, [rsi]		;caracter actual
	;si encuentra \n o \r o no digito, termina el numero
    cmp bl, 10                 ; '\n'
    je .store_number
    cmp bl, 13                 ; '\r'
    je .store_number
    cmp bl, '0'
    jl .store_number
    cmp bl, '9'
    jg .store_number
    ; rax = rax * 10 + (bl - '0')
    imul rax, rax, 10 		;multiplicando por 10
    movzx rdx, bl		;convierte en ASCII a 0 a 9
    sub rdx, '0'
    add rax, rdx		;actualiza acumulador
    inc rsi
    dec rcx
    jmp .parse_digits

.store_number:
    ; guardar rax (32-bit) en quantities[index]
    mov rbx, r15
    shl rbx, 2                 ; rbx = index * 4 (cada dd = 4 bytes)
    lea rdx, [rel quantities]
    add rdx, rbx
    mov dword [rdx], eax      ; almacena cantidad

    ; incrementar index y comprobar límite
    inc r15
    cmp r15, MAX_ITEMS
    jae .done_parse           ; llegamos al máximo de items soportados

    ; saltar hasta el final de la línea (si no estamos ya en '\n')
.skip_to_nl:
    cmp rcx, 0
    je .parse_loop
    mov al, [rsi]
    cmp al, 10
    je .advance_past_nl
    inc rsi
    dec rcx
    jmp .skip_to_nl

.advance_past_nl:
    inc rsi
    dec rcx
    jmp .parse_loop

.skip_line:
    ; salta el resto de la línea si no encontró ':'
.skip_line_loop:	;si linea no tiene :, avanza hasta final \b y se ignora linea y se vuelve al siguiente registro
    cmp rcx, 0
    je .parse_loop
    mov al, [rsi]
    inc rsi
    dec rcx
    cmp al, 10
    jne .skip_line_loop
    jmp .parse_loop

.done_parse:
    ; guardar count y cerrar archivo
    mov eax, r15d 	;copiar index a eax 
    mov [rel item_count], eax	;escribirlo en item_count

    ; close fd
    mov rdi, r12
    call file_close

    ; devolver count en rax
    mov rax, r15
    jmp .restore_and_ret

.cleanup_and_err:
    ; cerramos si es posible y retornamos error
    mov rax, -1	;error
    mov rdi, r12
    call file_close ;si falla duevuelve -1
    jmp .restore_and_ret

.err_return:
    mov rax, -1

.restore_and_ret:    ;Restaurar registros
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
