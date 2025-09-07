; main.asm
; lee inventario.txt y lo imprime

section .data
    filename db "inventario.txt", 0; cadenas de strings terminada en 0
;al llamarse file_open pasamos dir de filename en RDI
    buffer times 256 db 0          ; espacio para leer archivo(reserva 256 B en 0)

section .text
    global _start
    extern file_open, file_read, file_close
;etiquetas en otros objetos(para que linker sepa)

_start:
    ; Abrir archivo inventario.txt (O_RDONLY = 0)
    mov rdi, filename ;RDI tiene dir de file..
    mov rsi, 0            ; flags = solo lectura
    mov rdx, 0            ; mode = no aplica
    call file_open; para llamar desde io
    mov r12, rax          ; guardar descriptor de archivo

    ; Leer archivo
    mov rdi, r12 ;primer argumento
    mov rsi, buffer; segundo, bytes leidos
    mov rdx, 256; maximo de bytes
    call file_read
    mov r13, rax          ; bytes leídos

    ; Imprimir contenido
    mov rax, 1            ; sys_write
    mov rdi, 1            ; stdout=1, primer argumento
    mov rsi, buffer ;dir de datos a escribir
    mov rdx, r13 ;bytes a escribir
    syscall

    ; Cerrar archivo
    mov rdi, r12 ;coloca fd en RDI
    call file_close

    ; Salir del programa
    mov rax, 60
    xor rdi, rdi;poner RDI en 0
    syscall
