.include "config.inc"                                   ; I2C_BUS_RLOCK

; hardware I2C interface using USI

.equ    USIDR,                0x0f          ; USIDR – USI Data Register
.equ    USIBR,                0x10          ; USIBR – USI Buffer Register
.equ    USISR,                0x0e          ; USISR – USI Status Register
.equ    USICR,                0x0d          ; USICR – USI Control Register

.equ	USIOIF,               6	            ; Counter Overflow Interrupt Flag

.equ    I2C_MODE,             0b00101010      ; USIWM[1:0] set to 10, USICS[1:0] set to 10, USICLK set to 1
.equ    I2C_CLK_STROBE,       0b00101011      ; Write 1 to USITC bit
.equ    I2C_SDA_PIN,          0
.equ    I2C_SCL_PIN,          2



.equ    I2C_DELAY_CC,         1         ; this delays 1.25 us at 16 MHz. This is used for half a period.
                                        ; So for the full period, it is 2.5 us (400 kHz)
                                        ; * see 'timer_delay_clock_cycles' in the 'timer' module



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
    clr r16
    sts I2C_BUS_RLOCK, r16              ; clear i2c lock register
    pop r16

    rcall i2c_rlock_release
    ret


; i2c_deinit:
;     cbi DDRB, I2C_SDA_PIN               ; setup output I2C_SDA_PIN
;     cbi DDRB, I2C_SCL_PIN               ; setup output I2C_SCL_PIN

;     cbi PORTB, I2C_SDA_PIN              ; set SDA to high
;     cbi PORTB, I2C_SCL_PIN              ; set SCL to high

;     push r16
;     clr r16
;     out USIDR, r16
;     out USISR, r16
;     out USICR, r16
;     pop r16
;     ret


; -----------------------------
; I2C can only be used by one task at a time
; before using I2C, a task has to acquire the lock
;
; I2C_BUS_RLOCK - i2c reentrant lock register (1)
;    -------------------------------------------------------------------------------------
;    | RLKCNT3 | RLKCNT2 | RLKCNT1 | RLKCNT0 | TASKPTR3 | TASKPTR2 | TASKPTR1 | TASKPTR0 |
;    -------------------------------------------------------------------------------------
;   - i2c lock is task specific - meaning, each task can acquire locks multiple times (reentrant)
;           they only need to release it as many times to fully release the i2c lock
;   - a lock can be acquired only if RLKCNT (I2C_BUS_RLOCK[7:4]) is 0
;   - when a lock is acquired, I2C_BUS_RLOCK[3:0] is set to current TASKPTR value, and RLKCNT is incremented
;   - when a lock is released, RLKCNT is decremented. When it reaches 0, the lock is fully released
;   - tasks using i2c should use i2c_rlock_acquire and i2c_rlock_release
;       these routines facilitate wait-aquire-release workflow
;
; i2c_rlock_acquire will sleep till lock can be acquired
;   it returns once it is able to acquire the lock
i2c_rlock_acquire:
    push r16
    push r17
    rjmp _i2c_rlocked_wait

_i2c_rlock_wait_sleep:
    sei
    sleep
_i2c_rlocked_wait:
    cli                                 ; stop interrupts while checking and trying to acquire lock
    lds r17, TASKPTR
    lds r16, I2C_BUS_RLOCK
    cpi r16, 0x10                       ; quick way to check if top 4 bits are 0 (RLKCNT)
    brlo _i2c_rlock_available           ; RLKCNT is 0

    andi r16, 0x0f                      ; keep only bottom 4 bits (TSKPTR)
    cp r16, r17
    breq _i2c_rlock_available
    rjmp _i2c_rlock_wait_sleep          ; sleep till lock available

_i2c_rlock_available:
    lds r16, I2C_BUS_RLOCK
    swap r16
    inc r16                             ; increment RLKCNT
    swap r16

    andi r16, 0xf0                      ; wipe TASKPTR bits and reset it by or-ing with TASKPTR
    or r16, r17
    sts I2C_BUS_RLOCK, r16              ; acquire lock
    sei                                 ; enable interrupts and return
    pop r17
    pop r16
    ret


i2c_rlock_release:
    push r16
    lds r16, I2C_BUS_RLOCK
    cpi r16, 0x10                       ; quick way to check if top 4 bits are 0 (RLKCNT)
    brlo _i2c_rlock_done
    swap r16
    dec r16
    swap r16
    sts I2C_BUS_RLOCK, r16

_i2c_rlock_done:
    pop r16
    ret

; -----------------------------





i2c_do_start_condition:
    push r20

    ldi r20, I2C_DELAY_CC               ; set delay

    ; Release SCL to ensure that (repeated) Start can be performed
    sbi PORTB, I2C_SCL_PIN              ; set SCL to high
    sbi DDRB, I2C_SDA_PIN               ; make sure SDA is set as output
    rcall timer_delay_clock_cycles

    ; Generate Start Condition
    cbi PORTB, I2C_SDA_PIN              ; Force SDA LOW.
    rcall timer_delay_clock_cycles
    sbi USICR, 0                        ; Pull SCL LOW.

    sbi PORTB, I2C_SDA_PIN              ; Release SDA.

    ldi r20, I2C_MODE
    out USICR, r20

    pop r20
    ret



i2c_do_stop_condition:
    push r20

    ldi r20, I2C_DELAY_CC               ; set delay
    rcall timer_delay_clock_cycles

    cbi PORTB, I2C_SDA_PIN              ; set SDA to low
    sbi USICR, 0                        ; bring clock high
    rcall timer_delay_clock_cycles
    sbi PORTB, I2C_SDA_PIN              ; set SDA to high
    ldi r20, 0xf0                       ; Cleaning the flags and the counter is reset
    out USISR, r20

    pop r20
    ret



_i2c_pulse_till_overflow:
    push r20
    push r16

    ldi r20, I2C_DELAY_CC            ; set delay

_next_pulse:
    rcall timer_delay_clock_cycles
    sbi USICR, 0                    ; Generate positive SCL edge.   ; [TODO] handle clock stretching
    rcall timer_delay_clock_cycles
    sbi USICR, 0                    ; Generate negative SCL edge.

    in r16, USISR
    sbrs r16, USIOIF                ; Check for transfer complete.
    rjmp _next_pulse

    pop r16
    pop r20
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



internal_i2c_read_byte:
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
    rcall internal_i2c_read_byte
    ret

i2c_read_byte_nack:                           ; read one byte and send back NACK
    ldi r16, 0xff
    rcall internal_i2c_read_byte
    ret
