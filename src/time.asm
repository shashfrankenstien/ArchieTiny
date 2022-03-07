.include "config.inc"                                   ; TIME_SOFT_COUNTER

; 24 bit time counter
; HIGH_BYTE:MIDDLE_BYTE:LOW_BYTE
; TIME_SOFT_COUNTER+2:TIME_SOFT_COUNTER+1:TIME_SOFT_COUNTER
.equ    HIGH_BYTE,         TIME_SOFT_COUNTER
.equ    MIDDLE_BYTE,       TIME_SOFT_COUNTER + 1
.equ    LOW_BYTE,          TIME_SOFT_COUNTER + 2


time_init:
    sts LOW_BYTE, 0                               ; intialize counter registers to 0
    sts MIDDLE_BYTE, 0
    sts HIGH_BYTE, 0
    ret



time_tick:
    push r16
    push r17
    in r17, SREG

    lds r16, LOW_BYTE
    inc r16                                 ; increment may cause zero flag to be set
    sts LOW_BYTE, r16
    breq _tick_middle                       ; if zero flag is set, branch to next byte
    rjmp _tick_done

_tick_middle:
    lds r16, MIDDLE_BYTE
    inc r16                                 ; increment may cause zero flag to be set
    sts MIDDLE_BYTE, r16
    breq _tick_middle                       ; if zero flag is set, branch to next byte
    rjmp _tick_done

_tick_high:
    lds r16, HIGH_BYTE
    inc r16                                 ; increment may cause zero flag to be set
    sts HIGH_BYTE, r16

_tick_done:
    out SREG, r17
    pop r17
    pop r16
    ret



time_delay_ms_test:                              ; delay in ms, reads input from r18:r17:r16
    .irp param,12,13,14,15,16,17,18,19
        push r\param
    .endr
    in r12, SREG

    ldi r16, 200
    clr r17
    clr r18

    lds r19, LOW_BYTE
    adc r16, r19
    lds r19, MIDDLE_BYTE
    adc r17, r19
    lds r19, HIGH_BYTE
    adc r18, r19

_delay_loop:
    lds r13, LOW_BYTE
    lds r14, MIDDLE_BYTE
    lds r15, HIGH_BYTE

    sub r13, r16
    sbc r14, r17
    sbc r15, r18
_delay_loop2:
    ; brmi _delay_loop

    out SREG, r12
    .irp param,19,18,17,16,15,14,13,12
        pop r\param
    .endr
    ret
