; main.asm


section .data
    filename db "inventario.txt", 0; cadenas de strings terminada en 0
;al llamarse file_open pasamos dir de filename en RDI

section .text
    global _start
    extern load_inventory  ;viene de parse


_start:
    lea rdi, [rel filename]
    call load_inventory; devuelve RAX=count

    ; Salir del programa
    mov rax, 60
    xor rdi, rdi;poner RDI en 0
    syscall
