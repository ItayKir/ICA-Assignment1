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
    ; 1. Check command-line argument count (argc in rdi)
    ; 2. Parse argv strings (argv in rsi) into 64-bit integers 
    ; 3. Implement fraction addition: (n1*d2 + n2*d1) / (d1*d2)
    ; 4. Implement the GCD algorithm to reduce the sum [cite: 68]
    ; 5. Handle edge cases (Zero, NaN, +∞, -∞) [cite: 71, 72, 73, 74]
    ; 6. Print the result

    xor rax, rax
    ret