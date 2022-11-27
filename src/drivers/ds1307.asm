; RTC

.equ RTC_ADDR,                 0b01101000
.equ RTC_WRITE_ADDR,           (RTC_ADDR<<1) | 0x00            ; 0xd0
.equ RTC_READ_ADDR,            (RTC_ADDR<<1) | 0x01            ; 0xd1


rtc_init:
    push r16
    push r17

    clr r16
    clr r17
    rcall rtc_io_open_writer
    rcall i2c_send_byte
    rcall rtc_io_close
    pop r17
    pop r17
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
