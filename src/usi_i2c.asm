
.equ    USIDR,                0x0f          ; USIDR – USI Data Register
.equ    USIBR,                0x10          ; USIBR – USI Buffer Register
.equ    USISR,                0x0e          ; USISR – USI Status Register
.equ    USICR,                0x0d          ; USICR – USI Control Register

.equ	USIOIF,               6	            ; Counter Overflow Interrupt Flag

.equ    I2C_MODE,             0b00101010      ; USIWM[1:0] set to 10, USICS[1:0] set to 10, USICLK set to 1
.equ    I2C_CLK_STROBE,       0b00101011      ; Write 1 to USITC bit
.equ    I2C_SDA_PIN,          0
.equ    I2C_SCL_PIN,          2



; the `time_delay_ms` routine in the `time` module has a max frequency of 1 kHz (1 ms precision)
; this, however, is too slow to use i2c for anything practical
; so we will define an accurate clock cycle delay routine
; note: this is not truely accurate due to interrupts
;
; to go about it, we will count out the clock cycles of each instruction
; setup and tear down are one time. these should be subtracted
; instructions within the loop are doing the actual chunk of the work. this is the divisor
; so, the input in r20 should be (required delay - sum of setup and tear down instruction) / sum of loop instructions
delay_clock_cycles:                 ; create accurate delay
                                    ; +3 cycles -> rcall into delay_clock_cycles
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
    ret                             ; +4 cycles -> ret
; so finally,
;   sum of setup and tear down instruction = 12
;   sum of loop instructions = 4
; input r20 = (required delay - 12) / 4
; delay = lambda r20: (r20 * 4) + 12

; minimum delay is 15 clock cycles. r20 = 1
; common delays lookup table
; ------------------------------------------------
;   r20   |  delay (cycles)  | Time (16 MHz clock)
; ------------------------------------------------
;    1    |       16         |       1 us           ; min
;    2    |       20         |       1.25 us
;    7    |       40         |       2.5 us
;    17   |       80         |       5 us
;    22   |       100        |
;    37   |       160        |       10 us
;    47   |       200        |
;    72   |       300        |
;    197  |       800        |       50 us
;    255  |       1032       |       64.5 us        ; max
; ----------------------------



.equ    I2C_DELAY_CC,         2         ; this delays 1.25 us for 1/2 period. So for the full period, it is 400 kHz



i2c_init:
    sbi PORTB, I2C_SDA_PIN              ; set SDA to high
    sbi PORTB, I2C_SCL_PIN              ; set SCL to high

    sbi DDRB, I2C_SDA_PIN               ; setup output I2C_SDA_PIN
    sbi DDRB, I2C_SCL_PIN               ; setup output I2C_SCL_PIN

    push r16
    ldi r16, 0xff
    out USIDR, r16
    ldi r16, 0xf0                       ; Cleaning the flags and the counter is reset
    out USISR, r16
    ldi r16, I2C_MODE
    out USICR, r16
    pop r16
    ret

i2c_deinit:
    cbi DDRB, I2C_SDA_PIN               ; setup output I2C_SDA_PIN
    cbi DDRB, I2C_SCL_PIN               ; setup output I2C_SCL_PIN

    cbi PORTB, I2C_SDA_PIN              ; set SDA to high
    cbi PORTB, I2C_SCL_PIN              ; set SCL to high

    push r16
    clr r16
    out USIDR, r16
    out USISR, r16
    out USICR, r16
    pop r16
    ret




i2c_do_start_condition:
    .irp param,20,21,22
        push r\param
    .endr

    clr r21
    clr r22
    ldi r20, I2C_DELAY_CC               ; set delay

    ; Release SCL to ensure that (repeated) Start can be performed
    sbi PORTB, I2C_SCL_PIN              ; set SCL to high
    sbi DDRB, I2C_SDA_PIN               ; make sure SDA is set as output
    rcall delay_clock_cycles

    ; Generate Start Condition
    cbi PORTB, I2C_SDA_PIN              ; Force SDA LOW.
    rcall delay_clock_cycles
    sbi USICR, 0                        ; Pull SCL LOW.

    sbi PORTB, I2C_SDA_PIN              ; Release SDA.

    ldi r20, I2C_MODE
    out USICR, r20

    .irp param,22,21,20
        pop r\param
    .endr
    ret



i2c_do_stop_condition:
    .irp param,20,21,22
        push r\param
    .endr

    clr r21
    clr r22
    ldi r20, I2C_DELAY_CC                       ; set delay
    rcall delay_clock_cycles

    ldi r20, 0xff
    out USIDR, r20
    sbi USICR, 0
    ldi r20, 0xf0                       ; Cleaning the flags and the counter is reset
    out USISR, r20

    .irp param,22,21,20
        pop r\param
    .endr
    ret



_i2c_pulse_till_overflow:
    .irp param,16,20,21,22
        push r\param
    .endr

    clr r21
    clr r22
    ldi r20, I2C_DELAY_CC                       ; set delay

_next_pulse:
    rcall delay_clock_cycles
    sbi USICR, 0                    ; Generate positive SCL edge.
    rcall delay_clock_cycles
    sbi USICR, 0                    ; Generate negative SCL edge.

    in r16, USISR
    sbrs r16, USIOIF                ; Check for transfer complete.
    rjmp _next_pulse

    .irp param,22,21,20,16
        pop r\param
    .endr
    ret



i2c_send_byte:                           ; send one byte and return ACK / NACK
    push r17

    out USIDR, r16
    ldi r17, 0xf0                       ; Cleaning the flags and the counter is reset
    out USISR, r17
    rcall _i2c_pulse_till_overflow      ; pulse till USISR counter overflows


    cbi DDRB, I2C_SDA_PIN               ; change SDA pin to input to check for ACK
    ldi r17, 0xfe                       ; set USISR to 0xfe. this causes overflow after 1 clock pulse
    out USISR, r17
    rcall _i2c_pulse_till_overflow      ; pulse till USISR counter overflows

    in r16, USIDR                       ; return ACK / NACK on back on r16

    ldi r17, 0xff
    out USIDR, r17
    sbi DDRB, I2C_SDA_PIN               ; cleanup - change SDA pin back to output

    pop r17
    ret



_i2c_read_byte:
    push r17

    cbi DDRB, I2C_SDA_PIN               ; change SDA pin to input

    ldi r17, 0xf0                       ; Cleaning the flags and the counter is reset
    out USISR, r17
    rcall _i2c_pulse_till_overflow      ; pulse till USISR counter overflows

    mov r17, r16                        ; r16 contains either 0x00 for ACK or 0xff for NACK. move it to 17
    in r16, USIDR                       ; return read data back on r16

    out USIDR, r17                      ; setup data for ACK/NACK out

    sbi DDRB, I2C_SDA_PIN               ; change SDA pin to output to send ACK
    ldi r17, 0xfe                       ; set USISR to 0xfe. this causes overflow after 1 clock pulse
    out USISR, r17
    rcall _i2c_pulse_till_overflow      ; pulse till USISR counter overflows

    ldi r17, 0xff
    out USIDR, r17                      ; cleanup

    pop r17
    ret


i2c_read_byte_ack:                           ; read one byte and send back ACK
    clr r16
    rcall _i2c_read_byte
    ret

i2c_read_byte_nack:                           ; read one byte and send back NACK
    ldi r16, 0xff
    rcall _i2c_read_byte
    ret
