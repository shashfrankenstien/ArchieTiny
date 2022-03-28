.include "config.inc"                                   ; TIME_SOFT_COUNTER

; 24 bit software time counter

; HIGH_BYTE:MIDDLE_BYTE:LOW_BYTE
; TIME_SOFT_COUNTER+2:TIME_SOFT_COUNTER+1:TIME_SOFT_COUNTER

.equ    HIGH_BYTE,         TIME_SOFT_COUNTER
.equ    MIDDLE_BYTE,       TIME_SOFT_COUNTER + 1
.equ    LOW_BYTE,          TIME_SOFT_COUNTER + 2


time_init:
    sts LOW_BYTE, 0                          ; intialize counter registers to 0
    sts MIDDLE_BYTE, 0
    sts HIGH_BYTE, 0
    ret



time_tick:
    push r16
    push r17
    in r17, SREG

    lds r16, LOW_BYTE
    inc r16                                 ; increment may cause zero flag to be set
    sts LOW_BYTE, r16                       ; does not touch zero flag
    breq _tick_middle                       ; if zero flag is set, branch to next byte
    rjmp _tick_done

_tick_middle:
    lds r16, MIDDLE_BYTE
    inc r16                                 ; increment may cause zero flag to be set
    sts MIDDLE_BYTE, r16                    ; does not touch zero flag
    breq _tick_high                         ; if zero flag is set, branch to next byte
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



time_delay_ms:                              ; delay in ms, reads input from r18:r17:r16
    .irp param,16,17,18,19,20,21,22
        push r\param
    .endr
    in r22, SREG

    cli                                     ; read current timer 24 bit value. disable interrupt so this doesn't change while reading
    lds r19, LOW_BYTE
    lds r20, MIDDLE_BYTE
    lds r21, HIGH_BYTE

    clc                                     ; add current tick to the input values in r16, r17 and r18
    add r16, r19                            ; this gives us the target tick to wait for in _delay_loop
    adc r17, r20
    adc r18, r21
    sei                                     ; enable interrupts at the end

    rjmp _delay_loop

_delay_loop_sleep_jmp:
    sleep

_delay_loop:
    cli                                     ; read current timer 24 bit value. disable interrupt so this doesn't change while reading
    lds r19, LOW_BYTE
    lds r20, MIDDLE_BYTE
    lds r21, HIGH_BYTE

    clc                                     ; subtract target from current tick
    sub r19, r16                            ; this will be negative if target is in the future
    sbc r20, r17
    sbc r21, r18
    sei                                     ; sei does not mess with negative or zero flags used by brmi
    brmi _delay_loop_sleep_jmp              ; if subtracting target from current tick yielded a negative result, continue waiting

stopper_count:
    out SREG, r22
    .irp param,22,21,20,19,18,17,16
        pop r\param
    .endr
    ret
