; main.asm


section .data
    filename_cfg db "config.ini", 0
    filename db "inventario.txt", 0; cadenas de strings terminada en 0
;al llamarse file_open pasamos dir de filename en RDI

section .text
    global _start
    extern load_config
    extern load_inventory  ;viene de parse
    extern sort_inventory
    extern draw_graph


_start:
	;llamar configuracion
    lea rdi, [rel filename_cfg]
    call load_config
    cmp rax, 0
    jl .exit_error

	;leer inventario	
    lea rdi, [rel filename]
    call load_inventory; devuelve RAX=count
    cmp rax, 0
    jle .exit_error

	;ordenar
    mov rdi, rax
    call sort_inventory

	;graficar
    mov rdi, rax
    call draw_graph

.exit_ok:

    ; Salir del programa
    mov rax, 60
    xor rdi, rdi;poner RDI en 0
    syscall

.exit_error:
    mov rax, 60
    mov rdi, 1
    syscall

