.include "config.inc"                                   ; TIME_SOFT_COUNTER

; 24 bit software time counter
; kinda accurate clock cycle counter delay. (see time_delay_clock_cycles)

; HIGH_BYTE:MIDDLE_BYTE:LOW_BYTE
; TIME_SOFT_COUNTER+2:TIME_SOFT_COUNTER+1:TIME_SOFT_COUNTER

.equ    HIGH_BYTE,         TIME_SOFT_COUNTER
.equ    MIDDLE_BYTE,       TIME_SOFT_COUNTER + 1
.equ    LOW_BYTE,          TIME_SOFT_COUNTER + 2


time_init:
    clr r1
    sts LOW_BYTE, r1                         ; intialize counter registers to 0
    sts MIDDLE_BYTE, r1
    sts HIGH_BYTE, r1
    ret



time_tick_isr:
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
    reti




; 'time_delay_ms' takes 3 bytes in r22:r21:r20 which stands for number of ms to sleep
time_delay_ms:                              ; delay in ms, reads input from r22:r21:r20
    .irp param,16,17,18,19,20,21,22
        push r\param
    .endr
    in r19, SREG

    cli                                     ; read current timer 24 bit value. disable interrupt so this doesn't change while reading
    lds r16, LOW_BYTE
    lds r17, MIDDLE_BYTE
    lds r18, HIGH_BYTE

    clc                                     ; add current tick to the input values in r20, r21 and r22
    add r20, r16                            ; this gives us the target tick to wait for in _delay_loop
    adc r21, r17
    adc r22, r18
    sei                                     ; enable interrupts at the end

    rjmp _delay_loop

_delay_loop_sleep_jmp:
    sleep

_delay_loop:
    cli                                     ; read current timer 24 bit value. disable interrupt so this doesn't change while reading
    lds r16, LOW_BYTE
    lds r17, MIDDLE_BYTE
    lds r18, HIGH_BYTE

    clc                                     ; subtract target from current tick
    sub r16, r20                            ; this will be negative if target is in the future
    sbc r17, r21
    sbc r18, r22
    sei                                     ; sei does not mess with negative or zero flags used by brmi
    brmi _delay_loop_sleep_jmp              ; if subtracting target from current tick yielded a negative result, continue waiting

stopper_count:
    out SREG, r19
    .irp param,22,21,20,19,18,17,16
        pop r\param
    .endr
    ret



; 'time_delay_ms_short' is a special case when we want to delay less than 256 ms
; takes 1 byte in r20 which stands for number of ms to sleep
time_delay_ms_short:                        ; delay in ms, reads input from r22:r21:r20
    push r21
    push r22

    clr r21
    clr r22
    rcall time_delay_ms

    pop r22
    pop r21
    ret


; the `time_delay_ms` routine has a max frequency of 1 kHz (1 ms precision)
; this, however, is too slow to use in some cases (ex: i2c)
; so we will define an accurate clock cycle delay routine
; note: this is not truely accurate due to interrupts
;
; to go about it, we will count out the clock cycles of each instruction in the routine
; setup and tear down happen once. these should be subtracted from the required delay
; instructions within the loop are doing the actual chunk of the work. this is the divisor
; so, the input in r20 should be (required delay - sum of setup and tear down instruction) / sum of loop instructions
time_delay_clock_cycles:            ; create accurate delay
                                    ; +3 cycles -> rcall into time_delay_clock_cycles
    push r20                        ; +2 cycles -> push
    push r16                        ; +2 cycles -> push
    in r16, SREG                    ; +1 cycle -> in

_consume_clock:                     ; ----- loop -------
    nop                             ; +1 cycle -> nop
    dec r20                         ; +1 cycle -> dec
    brne _consume_clock             ; +2 cycles -> when brne is true
                                    ; ------------------
                                    ; -1 cycle -> brne takes only 1 cycle on the last loop, but we counted it as 2

    out SREG, r16                   ; +1 cycle -> out
    pop r16                         ; +2 cycles -> pop
    pop r20                         ; +2 cycles -> pop
    ret                             ; +4 cycles -> ret
; so finally,
;   sum of setup and tear down instruction = 16
;   sum of loop instructions = 4
; input r20 = (required delay - 16) / 4
; delay = lambda r20: (r20 * 4) + 16

; minimum delay is 20 clock cycles when r20 = 1
; common delays lookup table
; -------------------------------------------------
;   r20   |  delay (cycles)  | Time (16 MHz clock)
; -------------------------------------------------
;    1    |       20         |       1.25 us         ; min
;    2    |       24         |       1.5 us
;    3    |       28         |       1.75 us
;    6    |       40         |       2.5 us
;    16   |       80         |       5 us
;    21   |       100        |
;    36   |       160        |       10 us
;    56   |       240        |       20 us
;    96   |       400        |       30 us
;    196  |       800        |       50 us
;    255  |       1036       |       64.75 us        ; max
; -------------------------------------------------

