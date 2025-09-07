;io.asm archivo para manejar archivos externos del main

section .text ;codigos ejecutables
	global file_open
	global file_read
	global file_close

; int file_open(const char* filename, int flags, int mode) recibe estos 3 argumentos
; Devuelve descriptor de archivo en RAX o error
file_open:
    mov rax, 2          ; sys_open = 2
    mov rdi, rdi        ; filename (puntero)
    mov rsi, rsi        ; flags
    mov rdx, rdx        ; mode
    syscall ; toma argumentos desde RDI/RSI/RDX
    ret; renorna el valor que quedo en RAX

; ssize_t file_read(int fd, char* buf, size_t count)/ lectura de archivo
; Devuelve cantidad de bytes leídos en RAX
file_read:;leii hasta count bytes de gb hasta buf
    mov rax, 0          ; sys_read
    mov rdi, rdi        ; fd
    mov rsi, rsi        ; buffer
    mov rdx, rdx        ; count
    syscall ;da valores de RAX
    ret; lo retorna

; int file_close(int fd)/ cierra fd
file_close:
    mov rax, 3          ; sys_close
    mov rdi, rdi        ; fd
    syscall
    ret
