section .data:
    fmt_plus_infinity:      db 0x2b, 0xe2, 0x88, 0x9e, 0x00 ; for +∞
    fmt_minus_infinity:     db 0x2d, 0xe2, 0x88, 0x9e, 0x00 ; for −∞

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
    cmp rdi, 3                  
    je args_ok

usage_error:
    mov rdi, qword [stderr]     
    lea rsi, [fmt_usage]        
    xor rax, rax                
    call fprintf                

    mov rax, 1                  
    ret

args_ok:
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

; 1. Calculate the left side of the numerator addition: (n1 * d2)
    mov rax, r12                   ; Copy n1 into rax
    imul rax, r15                  ; Multiply rax by d2 (rax = n1 * d2)
    
    ; 2. Calculate the right side of the numerator addition: (n2 * d1)
    mov r8, r14                    ; Copy n2 into r8
    imul r8, r13                   ; Multiply r8 by d1 (r8 = n2 * d1)
    
    ; 3. Combine them to get the new unreduced numerator
    add rax, r8                    ; Add the two results (rax = n1*d2 + n2*d1)
    
    ; 4. Calculate the new denominator: (d1 * d2)
    mov rcx, r13                   ; Copy d1 into rcx
    imul rcx, r15                  ; Multiply rcx by d2 (rcx = d1 * d2)
    
    ; 5. Store the results safely back into our callee-saved registers
    mov r12, rax                   ; Overwrite r12 with the new numerator
    mov r13, rcx                   ; Overwrite r13 with the new denominator    

    mov rax, r12                   ; Copy numerator into rax (will be 'a')
    cmp rax, 0
    jge .num_positive              ; If numerator >= 0, skip negation
    neg rax                        ; Make rax positive (a = abs(numerator))
.num_positive:

    mov r8, r13                    ; Copy denominator into r8 (will be 'b')

    ; 2. The Euclidean Algorithm Loop: while (b != 0) { temp=b; b=a%b; a=temp; }
.gcd_loop:
    cmp r8, 0                      ; Check if b == 0
    je .gcd_done                   ; If b is 0, 'a' (rax) contains the GCD

    xor rdx, rdx                   ; Clear rdx to prepare for unsigned division
    div r8                         ; Unsigned divide: rdx:rax / r8
                                   ; rax = quotient, rdx = remainder (a % b)
    
    mov rax, r8                    ; a = old b
    mov r8, rdx                    ; b = remainder
    jmp .gcd_loop                  ; Repeat the loop
    
.gcd_done:
    ; 3. Safety Check: If GCD is 0, skip reduction to avoid a crash
    cmp rax, 0
    je .reduction_done             ; Both inputs were 0 (e.g., 0/0 -> NaN)

    mov r9, rax                    ; Save our found GCD into r9 safely

    ; 4. Reduce the Denominator
    ; (Since r13 is guaranteed positive, we can safely use unsigned div directly)
    mov rax, r13                   ; Load the denominator into rax
    xor rdx, rdx                   ; Clear rdx for unsigned division
    div r9                         ; Unsigned divide: rax = denominator / GCD
    mov r13, rax                   ; Store the reduced denominator back into r13

    ; 5. Reduce the Numerator (Using idiv natively!)
    mov rax, r12                   ; Load the original, signed numerator into rax
    cqo                            ; Sign-extend rax into rdx:rax
    idiv r9                        ; Signed divide: rax = numerator / GCD
    mov r12, rax                   ; Store the reduced numerator back into r12

.reduction_done:
; 1. Check for Zero Denominator edge cases (NaN, +∞, -∞)
    cmp r13, 0
    jne .check_zero_numerator      ; If denominator is not 0, move to standard checks

    ; -- We have a zero denominator --
    cmp r12, 0
    je .print_nan                  ; If numerator is also 0 -> NaN
    jg .print_plus_inf             ; If numerator > 0 -> +∞
    jl .print_minus_inf            ; If numerator < 0 -> -∞

.check_zero_numerator:
    ; 2. Check if the numerator is 0 (and denominator is not 0)
    cmp r12, 0
    je .print_zero                 ; If numerator is 0 -> print 0

    ; 3. Check if the denominator is 1
    cmp r13, 1
    je .print_integer              ; If denominator is 1 -> print as an integer

.print_fraction:
    ; 4. Standard fraction printing (e.g., "3/4")
    lea rdi, [fmt_fraction]        ; Load "%ld/%ld\n" into first argument
    mov rsi, r12                   ; Load numerator into second argument
    mov rdx, r13                   ; Load denominator into third argument
    xor rax, rax                   ; Clear rax for variadic function
    call printf
    jmp .end_program

.print_nan:
    lea rdi, [fmt_nan]             ; Load 'NaN ("not a number")\n'
    xor rax, rax
    call printf
    jmp .end_program

.print_plus_inf:
    lea rdi, [fmt_plus_infinity]   ; Load "+∞"
    xor rax, rax
    call printf
    jmp .print_newline             ; Jump to print a newline

.print_minus_inf:
    lea rdi, [fmt_minus_infinity]  ; Load "-∞"
    xor rax, rax
    call printf
    jmp .print_newline             ; Jump to print a newline

.print_zero:
    lea rdi, [fmt_integer]         ; Load "%ld\n"
    mov rsi, 0                     ; Set value to print as 0
    xor rax, rax
    call printf
    jmp .end_program

.print_integer:
    lea rdi, [fmt_integer]         ; Load "%ld\n"
    mov rsi, r12                   ; Set value to print as the numerator
    xor rax, rax
    call printf
    jmp .end_program

.print_newline:
    ; 5. Print the missing newline using printf instead of putchar
    lea rdi, [fmt_newline]         ; Load our dedicated newline string
    xor rax, rax                   ; Clear rax for variadic function
    call printf                    ; Call C library printf
    ; Fall through to .end_program

.end_program:
    mov rax, 0                     ; Set return code to 0 (success)
    ret                            ; Exit program

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

section .note.GNU-stack noalloc noexec