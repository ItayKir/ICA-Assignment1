section .data:
    fmt_plus_infinity:      db 0x2b, 0xe2, 0x88, 0x9e, 0x00 ; for +∞
    fmt_minus_infinity:     db 0x2d, 0xe2, 0x88, 0x9e, 0x00 ; for −∞

    fmt_nan:                db 'NaN ("not a number")', 10, 0

    fmt_usage:              db "Usage: program frac1 frac2,", 10
                            db "where frac can be either nat or nat/nat", 10, 0

    fmt_fraction:           db "%ld/%ld", 10, 0
    fmt_integer:            db "%ld", 10, 0

section .text
    global main
    extern printf
    extern fprintf
    extern stderr

main:
    ; 1. Check command-line argument count (argc in rdi) - V
    ; 2. Parse argv strings (argv in rsi) into 64-bit integers 
    ; 3. Implement fraction addition: (n1*d2 + n2*d1) / (d1*d2)
    ; 4. Implement the GCD algorithm to reduce the sum [cite: 68]
    ; 5. Handle edge cases (Zero, NaN, +∞, -∞) [cite: 71, 72, 73, 74]
    ; 6. Print the result
    cmp rdi, 3                  
    je .args_ok

usage_error:
    mov rdi, qword [stderr]     
    lea rsi, [fmt_usage]        
    xor rax, rax                
    call fprintf                

    mov rax, 1                  
    ret

    ; 1. Extract first argument (argv[1])
    mov rdi, qword [rsi + 8]       ; Load pointer to frac1 string
    call parse_fraction            ; Returns: rax = num1, rcx = den1
    mov r12, rax                   ; Store num1 in callee-saved register r12
    mov r13, rcx                   ; Store den1 in callee-saved register r13
    
    ; 2. Extract second argument (argv[2])
    mov rdi, qword [rsi + 16]      ; Load pointer to frac2 string
    call parse_fraction            ; Returns: rax = num2, rcx = den2
    mov r14, rax                   ; Store num2 in callee-saved register r14
    mov r15, rcx                   ; Store den2 in callee-saved register r15

parse_fraction:
    call parse_int                 ; Parse the numerator
    mov r8, rax                    ; Temporarily park the numerator in r8
    
    mov rcx, 1                     ; Default the denominator to 1
    cmp byte [rdi], 0              ; Check if we reached the null terminator
    je .frac_done                  ; If yes, it's just an integer; we are done
    
    cmp byte [rdi], '/'            ; Check if the current character is a slash
    jne usage_error                ; If it's not a null and not a '/', it's invalid
    
    inc rdi                        ; Advance pointer past the '/'
    call parse_int                 ; Parse the denominator
    mov rcx, rax                   ; Move the parsed denominator into rcx
    
    cmp byte [rdi], 0              ; Ensure no extra characters exist after the denominator
    jne usage_error

.frac_done:
    mov rax, r8                    ; Restore the numerator back to rax for the return
    ret

parse_int:
    xor rax, rax                   ; Initialize accumulator to 0
    mov r9, 1                      ; Initialize sign multiplier to positive 1
    
    cmp byte [rdi], '-'            ; Check for negative sign
    jne .parse_loop                ; If not negative, jump to parsing digits
    mov r9, -1                     ; Set sign multiplier to -1
    inc rdi                        ; Advance pointer past the '-'
    
.parse_loop:
    ; 1. Direct memory comparisons (no need for 'b' registers)
    cmp byte [rdi], '0'            ; Check if the byte in memory is less than ASCII '0'
    jl .int_done                   ; If so, we've hit a non-digit (like '/' or null)
    cmp byte [rdi], '9'            ; Check if the byte in memory is greater than ASCII '9'
    jg .int_done                   ; If so, we've hit a non-digit
    
    imul rax, 10                   ; Multiply our running total by 10
    
    ; 2. Safely load the 8-bit character into a 64-bit register without movzx
    xor rcx, rcx                   ; Clear the entire 64-bit rcx register to all zeros
    mov cl, byte [rdi]             ; Move the 8-bit character into cl (the lowest byte of rcx)
                                   ; rcx now safely holds the 64-bit equivalent of the character

    sub rcx, '0'                   ; Convert ASCII character to literal integer (e.g., '5' -> 5)
    add rax, rcx                   ; Add the new digit to our running total
    
    inc rdi                        ; Advance the pointer to the next character
    jmp .parse_loop                ; Repeat the loop
    
.int_done:
    imul rax, r9                   ; Multiply the final number by our sign (1 or -1)
    ret

parse_int:
    xor rax, rax                   ; Initialize accumulator to 0
    mov r9, 1                      ; Initialize sign multiplier to positive 1
    
    cmp byte [rdi], '-'            ; Check for negative sign
    jne .parse_loop                ; If not negative, jump to parsing digits
    mov r9, -1                     ; Set sign multiplier to -1
    inc rdi                        ; Advance pointer past the '-'
    
.parse_loop:
    ; 1. Direct memory comparisons (no need for 'b' registers)
    cmp byte [rdi], '0'            ; Check if the byte in memory is less than ASCII '0'
    jl .int_done                   ; If so, we've hit a non-digit (like '/' or null)
    cmp byte [rdi], '9'            ; Check if the byte in memory is greater than ASCII '9'
    jg .int_done                   ; If so, we've hit a non-digit
    
    imul rax, 10                   ; Multiply our running total by 10
    
    ; 2. Safely load the 8-bit character into a 64-bit register without movzx
    xor rcx, rcx                   ; Clear the entire 64-bit rcx register to all zeros
    mov cl, byte [rdi]             ; Move the 8-bit character into cl (the lowest byte of rcx)
                                   ; rcx now safely holds the 64-bit equivalent of the character

    sub rcx, '0'                   ; Convert ASCII character to literal integer (e.g., '5' -> 5)
    add rax, rcx                   ; Add the new digit to our running total
    
    inc rdi                        ; Advance the pointer to the next character
    jmp .parse_loop                ; Repeat the loop
    
.int_done:
    imul rax, r9                   ; Multiply the final number by our sign (1 or -1)
    ret

    xor rax, rax
    ret