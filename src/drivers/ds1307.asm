; RTC

.equ RTC_ADDR,                 0b01101000
.equ RTC_WRITE_ADDR,           (RTC_ADDR<<1) | 0x00            ; 0xd0
.equ RTC_READ_ADDR,            (RTC_ADDR<<1) | 0x01            ; 0xd1


rtc_init:
    push r16
    push r17

    ; Bit 7 of Register 0 is the clock halt (CH) bit.
    ; When this bit is set to 1, the oscillator is disabled
    ; write 0 to address 0 to start the RTC and reset RTC clock
    clr r17
    rcall rtc_io_open_writer
    clr r16
    rcall i2c_send_byte
    rcall rtc_io_close
    pop r17
    pop r16
    ret


;   r17   ; rtc read address
rtc_io_open_reader:
    push r16
    rcall i2c_do_start_condition

    ldi r16, RTC_WRITE_ADDR
    rcall i2c_send_byte
    mov r16, r17
    rcall i2c_send_byte

    ; rcall i2c_do_stop_condition
    rcall i2c_do_start_condition               ; we send a restart event after which we will be able to read display RAM data

    ldi r16, RTC_READ_ADDR                     ; i2c communication to read
    rcall i2c_send_byte

    pop r16
    ret


;   r17   ; rtc write address
rtc_io_open_writer:
    push r16
    rcall i2c_do_start_condition

    ldi r16, RTC_WRITE_ADDR
    rcall i2c_send_byte
    mov r16, r17
    rcall i2c_send_byte
    pop r16
    ret


rtc_io_close:
    rcall i2c_do_stop_condition
    ret



; rtc_read_time:
;     push r16
;     push r17
;     clr r17
;     rcall i2c_rlock_acquire
;     rcall rtc_io_open_reader

;     rcall i2c_read_byte_ack             ; read second
;     sts RTC_SECOND, r16
;     rcall i2c_read_byte_ack             ; read minute
;     sts RTC_MINUTE, r16
;     rcall i2c_read_byte_nack            ; read hour
;     sts RTC_HOUR, r16
;     rcall rtc_io_close
;     rcall i2c_rlock_release
;     pop r17
;     pop r16
;     ret
