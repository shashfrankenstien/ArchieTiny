.include "config.inc"                                   ; TIME_SOFT_COUNTER


; timer / counter control - Timer0
; .equ    GTCCR,            0x2c            ; GTCCR – General Timer/Counter Control Register
.equ    TCCR0A,             0x2a            ; TCCR0A – Timer/Counter Control Register A
.equ    TCCR0B,             0x33            ; TCCR0B – Timer/Counter Control Register B
.equ    OCR0A,              0x29            ; OCR0A – Output Compare Register A
.equ    OCR0B,              0x28            ; OCR0B – Output Compare Register B
.equ    TCNT0,              0x32            ; TCNT0 – Timer/Counter Register
.equ    TIMSK,              0x39            ; TIMSK – Timer/Counter Interrupt Mask Registe
.equ    TIFR,               0x38            ; TIFR – Timer/Counter Interrupt Flag Register

.equ    COUNTER_CTRL_A,     0b00000010      ; mode - 10 = Clear Timer on Compare Match (CTC) mode - resets counter when compare matches OCR0A
.equ    COUNTER_CTRL_B,     0b00000011      ; clk setting (011 = 16 MHz / 64)

.equ    OCIE0A,             4               ; OCIE0A (Output Compare Interrupt Enable - Timer 0 - A) is the 4th bit of TIMSK
.equ    OCIE0B,             3               ; OCIE0B (Output Compare Interrupt Enable - Timer 0 - B) is the 3rd bit of TIMSK
.equ    TIMER_INT_MASK,     (1<<OCIE0A) | (1<<OCIE0B)   ; Timer 0 compare match A & B interrupts enabled

.equ    TIMER_COMPVAL_A,    250             ; using compare match A interrupt, timer counts from 0 to TIMER_COMPVAL_A, then resets to 0
                                            ; TIMER_COMPVAL_A value 250 = 1 millisecond
                                            ; this was arrived at using the below equation
                                            ; TIMER_COMPVAL_A = 0.001 * f_cpu / prescale_div
                                            ; if f_cpu = 16 MHz and selected prescale_div = 64, TIMER_COMPVAL_A = 250

.equ    TIMER_COMPVAL_B,    150             ; compare match B interrupt is triggered when TCNT0 reaches this value
                                            ; however, this interrupt will not reset the counter. It will always count up to TIMER_COMPVAL_A
                                            ; hence, the compare match B interrupt has the same frequency as compare match A

; -------------------------------------------------

; 24 bit software time counter
; kinda accurate clock cycle counter delay. (see timer_delay_clock_cycles)

; HIGH_BYTE:MIDDLE_BYTE:LOW_BYTE
; TIME_SOFT_COUNTER+2:TIME_SOFT_COUNTER+1:TIME_SOFT_COUNTER

.equ    HIGH_BYTE,         TIME_SOFT_COUNTER
.equ    MIDDLE_BYTE,       TIME_SOFT_COUNTER + 1
.equ    LOW_BYTE,          TIME_SOFT_COUNTER + 2


timer_init:
    ; initialize timer 0
    ldi r16, COUNTER_CTRL_A
    out TCCR0A, r16                 ; mode select

    ldi r16, COUNTER_CTRL_B
    out TCCR0B, r16                 ; clk select

    ldi r16, TIMER_COMPVAL_A
    out OCR0A, r16                  ; load compare A register

    ldi r16, TIMER_COMPVAL_B
    out OCR0B, r16                  ; load compare B register

    ldi r16, TIMER_INT_MASK
    out TIMSK, r16                  ; enable interrupt

    clr r16
    sts LOW_BYTE, r16               ; intialize counter registers to 0
    sts MIDDLE_BYTE, r16
    sts HIGH_BYTE, r16
    ret



timer_tick_isr:
    push r16

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
    pop r16
    reti




; 'timer_delay_ms' takes 3 bytes in r22:r21:r20 which stands for number of ms to sleep
timer_delay_ms:                              ; delay in ms, reads input from r22:r21:r20
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



; 'timer_delay_ms_short' is a special case when we want to delay less than 256 ms
; takes 1 byte in r20 which stands for number of ms to sleep
timer_delay_ms_short:                        ; delay in ms, reads input from r20
    push r21
    push r22

    clr r21
    clr r22
    rcall timer_delay_ms

    pop r22
    pop r21
    ret


; the `timer_delay_ms` routine has a max frequency of 1 kHz (1 ms precision)
; this, however, is too slow to use in some cases (ex: i2c)
; so we will define an accurate clock cycle delay routine
; note: this is not truely accurate due to interrupts
;
; to go about it, we will count out the clock cycles of each instruction in the routine
; setup and tear down happen once. these should be subtracted from the required delay
; instructions within the loop are doing the actual chunk of the work. this is the divisor
; so, the input in r20 should be (required delay - sum of setup and tear down instruction) / sum of loop instructions
timer_delay_clock_cycles:            ; create accurate delay
                                    ; +3 cycles -> rcall into timer_delay_clock_cycles
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
;    56   |       240        |       15 us
;    76   |       320        |       20 us
;    116  |       480        |       30 us
;    196  |       800        |       50 us
;    255  |       1036       |       64.75 us        ; max
; -------------------------------------------------

