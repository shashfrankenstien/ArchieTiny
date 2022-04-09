; http://www.avr-asm-tutorial.net/avr_en/calc/MULTIPLICATION.html

; Flow of multiplication
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
; 1.The binary multiplier, is shifted bitwise
;   into the carry bit. If carry is 1, the binary multiplicand
;   is added to the result
;
; 2.The binary multiplicand is rotated one position
;   to the left (multiplied by 2) shifting a 0 into the void position.
;
; 3.If the binary multiplier is not zero yet, the
;   multiplication loop is repeated. If it is zero, the
;   multiplication is complete.
;
;======= Software multiplication function (implementing mul) ============================
; input
;   r16    ; multiplicand
;   r17    ; multiplier
; 16 bit output (r17:r16)
;   r16     ; the low byte of the result
;   r17     ; the high byte of result
;-----------------------------------------------------------------------------------
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

