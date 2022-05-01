; http://www.avr-asm-tutorial.net/avr_en/calc/MULTIPLICATION.html

;======= Software multiplication function ============================
; deviates from MUL op-code in that it overwrites the
;   8 bit input registers r16 and r17 with the 16 bit return value r17:r16
;
;     decimal example:
; ------------------------
;     1234 * 567 = ?
; ------------------------
;     1234 * 7   =    8638
; +  12340 * 6   =   74040
; + 123400 * 5   =  617000
; ------------------------
;     1234 * 567 =  699678
; ========================
;
; Flow of multiplication
; 1.The binary multiplier, is shifted right bitwise
;   into the carry bit. If carry is 1, the binary multiplicand
;   is added to the result
;
; 2.The binary multiplicand is rotated one position
;   to the left (multiplied by 2) shifting a 0 into the void position.
;
; 3.If the binary multiplier is not zero yet, the
;   multiplication loop is repeated. If it is zero, the
;   multiplication is complete.
; ------------------------
; input
;   r16    ; multiplicand
;   r17    ; multiplier
; 16 bit output (r17:r16)
;   r16     ; the low byte of the result
;   r17     ; the high byte of result
mul8:
    push r18
    push r19
    push r20
    push r21

    in r18, SREG

    clr r19           ; clear temporary register to catch multiplicand overflow on shift left
    clr r20           ; clear the register to store the resulting low byte
    clr r21           ; clear the register to store the resulting high byte
_mul_1:
    lsr r17           ; right shift multiplier into carry
    brcc _mul_2       ; if carry is cleared (LSB of r17 was 0), then go to next step
                      ; if carry is set, add multiplicand to result
    add r20, r16      ; add the multiplicand to the low byte of the result
    adc r21, r19      ; add the multiplicand overflow to the high byte of the result
_mul_2:
    lsl r16           ; shift multiplicand to left for the next step (multiply by 2)
    rol r19           ; rotate the carry into temp variable

    tst r17           ; check if multiplier is empty
    brne _mul_1       ; go to next step if not empty

    mov r16, r20      ; move result back into r17:r16 and return
    mov r17, r21

    out SREG, r18

    pop r21
    pop r20
    pop r19
    pop r18
    ret

;-----------------------------------------------------------------------------------



; https://www.youtube.com/watch?v=v3-a-zqKfgA&t=1154s

;======= Software division function ============================
; deviates from DIV op-code in that it overwrites the
;   8 bit input registers r16 and r17 with the quotient in r16 and remainder in r17
;
;   decimal long division example:
; ------------------------
;      125 / 4   = ?
; ------------------------
;       12 / 4   =   3 -> 0
;       05 / 4   =   1 -> 1
; ------------------------
;      125 / 4   =   31 (remainder 1)
;
;
;   binary long division example:
; -------------------------------------------
;  01111101 / 100   = ?
; -------------------------------------------
;  (rol) 0 - 100            q = 0; d = 1111101
;  (rol) 01 - 100           q = 0; d = 111101
;  (rol) 011 - 100          q = 0; d = 11101
;  (rol) 0111 - 100 = 11    q = 1; d = 1101
;  (rol) 111 - 100 = 11     q = 1; d = 101
;  (rol) 111 - 100 = 11     q = 1; d = 01
;  (rol) 110 - 100 = 10     q = 1; d = 1
;  (rol) 101 - 100 = 1      q = 1; d = 0
; final remainder = 1
; -------------------------------------------
;  01111101 / 100   = 00011111 (remainder 1)
; ========================
;
; Flow of division
; 1.Dividend is rotated left (rol) into a tmp var,
;   and at earch rotation, we check if it can be subtracted by the divisor.
;
; 2.SUB can be used and the carry bit can be pushed to the quotient
;   If a subtraction is successful (carry is cleared), we copy the difference back into the tmp var
;
; 3.This process is continued till dividend becomes 0 (or just simply 8 times to get 8 bit quotient).
;   At this point, quotient will be inverted. So we flip all the bits (COM). Remainder is in tmp var
; ------------------------
; input
;   r16    ; dividend
;   r17    ; divisor
; output
;   r16    ; quotient
;   r17    ; remainder
div8:
    push r18
    push r19
    push r20
    push r21
    push r22

    in r18, SREG

    clr r19             ; clear temporary register (tmp var)
    ldi r22, 8
_div_start:
    clc
    rol r16             ; rotate MSB into carry
    rol r19             ; rotate bit into tmp var

    mov r20, r19
    sub r20, r17
    brsh _div_q
    rjmp _div_loop
_div_q:
    mov r19, r20        ; subtraction successful
_div_loop:
    rol r21             ; rotate carry in (inverse)
    dec r22
    brne _div_start

    com r21
    mov r16, r21
    mov r17, r19

    out SREG, r18

    pop r22
    pop r21
    pop r20
    pop r19
    pop r18
    ret
