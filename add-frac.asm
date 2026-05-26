section .data
    fmt_plus_infinity:      db 0x2b, 0xe2, 0x88, 0x9e, 0x00  ; for +∞
    fmt_minus_infinity:     db 0x2d, 0xe2, 0x88, 0x9e, 0x00  ; for −∞
    fmt_nan:                db 'NaN ("not a number")', 10, 0
    fmt_usage:              db "Usage: program frac1 frac2,", 10
                            db "where frac can be either nat or nat/nat", 10, 0
    fmt_fraction:           db "%ld/%ld", 10, 0
    fmt_integer:            db "%ld", 10, 0
    fmt_newline:            db 10, 0 

section .text
    global main
    extern printf
    extern fprintf
    extern stderr

main:
    ; check if we got 3 args total
    cmp rdi, 3                  
    je args_ok

usage_error:
    ; print usage to stderr on bad input
    mov rdi, qword [stderr]     
    lea rsi, [fmt_usage]        
    xor rax, rax                
    call fprintf                

    mov rax, 1                  
    ret

args_ok:
    ; parse first arg
    mov rdi, qword [rsi + 8]
    call parse_fraction
    mov r12, rax                   ; n1
    mov r13, rcx                   ; d1
    
    ; parse second arg
    mov rdi, qword [rsi + 16]
    call parse_fraction
    mov r14, rax                   ; n2
    mov r15, rcx                   ; d2

    ; do math: (n1*d2 + n2*d1) / (d1*d2)
    mov rax, r12
    imul rax, r15                  ; n1 * d2
    
    mov r8, r14
    imul r8, r13                   ; n2 * d1
    
    add rax, r8                    ; sum numerators
    
    mov rcx, r13
    imul rcx, r15                  ; new denom (d1 * d2)
    
    ; save unreduced result
    mov r12, rax
    mov r13, rcx

    ; start gcd algorithm
    mov rax, r12
    cmp rax, 0
    jge .num_positive
    neg rax                        ; make positive for gcd
.num_positive:

    mov r8, r13

.gcd_loop:
    cmp r8, 0
    je .gcd_done

    xor rdx, rdx
    div r8
    
    mov rax, r8
    mov r8, rdx
    jmp .gcd_loop
    
.gcd_done:
    ; reduce if gcd != 0
    cmp rax, 0
    je .reduction_done

    mov r9, rax

    ; reduce denom
    mov rax, r13
    xor rdx, rdx
    div r9
    mov r13, rax

    ; reduce num
    mov rax, r12
    cqo
    idiv r9
    mov r12, rax

.reduction_done:
    ; check edge cases for printing
    cmp r13, 0
    jne .check_zero_numerator

    ; denom is 0
    cmp r12, 0
    je .print_nan
    jg .print_plus_inf
    jl .print_minus_inf

.check_zero_numerator:
    cmp r12, 0
    je .print_zero

    cmp r13, 1
    je .print_integer

.print_fraction:
    lea rdi, [fmt_fraction]
    mov rsi, r12
    mov rdx, r13
    xor rax, rax
    call printf
    jmp .end_program

.print_nan:
    lea rdi, [fmt_nan]
    xor rax, rax
    call printf
    jmp .end_program

.print_plus_inf:
    lea rdi, [fmt_plus_infinity]
    xor rax, rax
    call printf
    jmp .print_newline

.print_minus_inf:
    lea rdi, [fmt_minus_infinity]
    xor rax, rax
    call printf
    jmp .print_newline

.print_zero:
    lea rdi, [fmt_integer]
    mov rsi, 0
    xor rax, rax
    call printf
    jmp .end_program

.print_integer:
    lea rdi, [fmt_integer]
    mov rsi, r12
    xor rax, rax
    call printf
    jmp .end_program

.print_newline:
    lea rdi, [fmt_newline]
    xor rax, rax
    call printf

.end_program:
    mov rax, 0
    ret

parse_fraction:
    call parse_int
    mov r8, rax                    ; save num
    
    mov rcx, 1                     ; default denom to 1
    cmp byte [rdi], 0
    je .frac_done
    
    cmp byte [rdi], '/'
    jne usage_error
    
    inc rdi
    call parse_int
    mov rcx, rax
    
    cmp byte [rdi], 0
    jne usage_error

.frac_done:
    mov rax, r8
    ret

parse_int:
    xor rax, rax
    mov r9, 1
    
    cmp byte [rdi], '-'
    jne .parse_loop
    mov r9, -1                     ; negative sign
    inc rdi
    
.parse_loop:
    cmp byte [rdi], '0'
    jl .int_done
    cmp byte [rdi], '9'
    jg .int_done
    
    imul rax, 10
    
    xor rcx, rcx
    mov cl, byte [rdi]
    sub rcx, '0'
    add rax, rcx
    
    inc rdi
    jmp .parse_loop
    
.int_done:
    imul rax, r9                   ; apply sign
    ret

section .note.GNU-stack noalloc noexec