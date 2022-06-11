; FRAM

.equ FRAM_ADDR,                 0b01010000
.equ FRAM_WRITE_ADDR,           (FRAM_ADDR<<1) | 0x00            ; 0xa0
.equ FRAM_READ_ADDR,            (FRAM_ADDR<<1) | 0x01            ; 0xa1


; read a byte from external fram memory
; input
;   r25:r24    ; fram read address
; output
;   r16        ; byte read
fram_read:
    rcall i2c_lock_acquire
    rcall i2c_do_start_condition

    ldi r16, FRAM_WRITE_ADDR
    rcall i2c_send_byte
    mov r16, r25
    rcall i2c_send_byte
    mov r16, r24
    rcall i2c_send_byte

    ; rcall i2c_do_stop_condition
    rcall i2c_do_start_condition               ; we send a restart event after which we will be able to read display RAM data

    ldi r16, FRAM_READ_ADDR                    ; i2c communication to read
    rcall i2c_send_byte

    rcall i2c_read_byte_nack                   ; perform read

    rcall i2c_do_stop_condition
    rcall i2c_lock_release
    ret



; ; write a byte to external fram memory
; ; input
; ;   r25:r24    ; fram write address
; ;   r16        ; byte to write
; fram_write:
;     push r16
;     rcall i2c_lock_acquire
;     rcall i2c_do_start_condition

;     ldi r16, FRAM_WRITE_ADDR
;     rcall i2c_send_byte
;     mov r16, r25
;     rcall i2c_send_byte
;     mov r16, r24
;     rcall i2c_send_byte

;     pop r16
;     rcall i2c_send_byte

;     rcall i2c_do_stop_condition
;     rcall i2c_lock_release
;     ret




;   r25:r24    ; fram read address
fram_io_open_reader:
    push r16
    rcall i2c_do_start_condition

    ldi r16, FRAM_WRITE_ADDR
    rcall i2c_send_byte
    mov r16, r25
    rcall i2c_send_byte
    mov r16, r24
    rcall i2c_send_byte

    ; rcall i2c_do_stop_condition
    rcall i2c_do_start_condition               ; we send a restart event after which we will be able to read display RAM data

    ldi r16, FRAM_READ_ADDR                    ; i2c communication to read
    rcall i2c_send_byte

    pop r16
    ret



;   r25:r24    ; fram write address
fram_io_open_writer:
    push r16
    rcall i2c_do_start_condition

    ldi r16, FRAM_WRITE_ADDR
    rcall i2c_send_byte
    mov r16, r25
    rcall i2c_send_byte
    mov r16, r24
    rcall i2c_send_byte
    pop r16
    ret


fram_io_close:
    rcall i2c_do_stop_condition
    ret
