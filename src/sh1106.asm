
; this program interfaces with SH1106 OLED display over i2c

.equ OLED_ADDR,              0b00111100
.equ OLED_WRITE_ADDR,        (OLED_ADDR << 1)
.equ OLED_READ_ADDR,         (OLED_ADDR << 1) | 0x01

; control byte                                       ; if bit 8 is set, we can send 1 data byte after this
.equ OLED_WRITE_DATA,        0b11000000              ; if bit 7 is set, indicates that the next byte needs to be stored in memory
.equ OLED_WRITE_CMD,         0b10000000              ; if bit 7 is clear, the next byte will be a command

.equ OLED_WRITE_DATA_LIST,   0b01000000
.equ OLED_WRITE_CMD_LIST,    0b00000000


; commands
.equ SET_DISPLY_OFF,         0xae                       ; 0b1010111x
.equ SET_DISPLY_ON,          0xaf                       ; where x is 1 for ON and 0 for OFF

.equ SET_PAGE_ADDRESS,       0xb0                       ; 0b10110xxx where xxx are page addresses 0 - 7
.equ SET_COLUMN_L,           0x00                       ; 0b0000xxxx where xxxx are column number low bits
.equ SET_COLUMN_H,           0x10                       ; 0b0001xxxx where xxxx are column number high bits

.equ SET_DISP_FREQ_MODE,     0xd5                       ; double command. use with DEFAULT_DISP_FREQ
.equ DEFAULT_DISP_FREQ,      0x50

.equ SET_COLOR_NORM,         0xa6                       ; normal = white fg, black bg
.equ SET_COLOR_INV,          0xa7                       ; inverted = black fg, white bg

.equ SET_COMM_SCAN_DIR_NORM, 0xc0                       ; normal = page numbers start on the end away from the i2c pinout
.equ SET_COMM_SCAN_DIR_INV,  0xc8                       ; inverted =  page numbers start on the end closer to the i2c pinout

.equ SET_SEGMENT_REMAP_NORM, 0xa0                       ; column scanning direction left to right or right to left
.equ SET_SEGMENT_REMAP_INV,  0xa1                       ; reverse of SET_SEGMENT_REMAP_NORM



oled_init:
    push r16
    rcall i2c_do_stop_condition                         ; call stop condition just in case (mostly not required)
    rcall i2c_do_start_condition

    ldi r16, OLED_WRITE_ADDR                            ; i2c communication always starts with the address + read/write flag
    rcall i2c_send_byte

    ldi r16, OLED_WRITE_CMD_LIST                        ; this control byte tells the display to expect a list of commands until stop condition
    rcall i2c_send_byte

    ldi r16, SET_DISPLY_ON                              ; turn on the display
    rcall i2c_send_byte
    ldi r16, SET_DISP_FREQ_MODE                         ; set the display refresh rate (double command)
    rcall i2c_send_byte
    ldi r16, DEFAULT_DISP_FREQ
    rcall i2c_send_byte

    ldi r16, SET_COMM_SCAN_DIR_INV                      ; flip the screen
    rcall i2c_send_byte
    ldi r16, SET_SEGMENT_REMAP_INV                      ; reverse the column scan direction
    rcall i2c_send_byte

    rcall i2c_do_stop_condition

    clr r16
    rcall oled_fill                                     ; fill oled with data in r16 (all 0s)

    pop r16
    ret




oled_fill:                                              ; fill screen with value in r16
    .irp param,17,18,19
        push r\param
    .endr

    mov r17, r16                                        ; save away page fill byte till later

    clr r18                                             ; page counter 0 to 7
_next_page:
    rcall i2c_do_stop_condition
    rcall i2c_do_start_condition

    ldi r16, OLED_WRITE_ADDR
    rcall i2c_send_byte

    ldi r16, OLED_WRITE_CMD
    rcall i2c_send_byte
    mov r16, r18                                        ; get current page number (loop iteration variable)
    ori r16, SET_PAGE_ADDRESS                           ; OR with SET_PAGE_ADDRESS cmd
    rcall i2c_send_byte

                                                        ; set cursor to column 0
    ldi r16, OLED_WRITE_CMD
    rcall i2c_send_byte
    ldi r16, SET_COLUMN_L | 2                           ; screen is somehow offset by 2 columns ?? :/
    rcall i2c_send_byte

    ldi r16, OLED_WRITE_CMD
    rcall i2c_send_byte
    ldi r16, SET_COLUMN_H
    rcall i2c_send_byte

    ldi r16, OLED_WRITE_DATA_LIST                       ; this tells the device to expect a list of data bytes until stop condition
    rcall i2c_send_byte

    clr r19                                             ; column counter 0 to 127
_next_column:
    mov r16, r17                                        ; load back fill byte that was originally saved in r17
    rcall i2c_send_byte                                 ; i2c_send_byte modifies r16, so we need to reload r16 at every iteration
    inc r19
    sbrs r19, 7                                         ; continue to next step if column reached 128
    rjmp _next_column

    inc r18
    sbrs r18, 3                                         ; continue to next step if page reached 8
    rjmp _next_page

    .irp param,19,18,17
        pop r\param
    .endr
    rcall i2c_do_stop_condition
    ret                                                 ; return value r16 will contain ACK from last byte transfered








test_oled:
    push r16

    ldi r16, 0x0f
    rcall oled_fill
    sbrs r16, 0
    cbi PORTB, 1
    pop r16
    ret

test_oled2:
    push r16

    ldi r16, 0xf0
    rcall oled_fill
    sbrs r16, 0
    cbi PORTB, 1
    pop r16
    ret
    ret


test_oled_read:
    ; rcall i2c_init
    rcall i2c_do_start_condition
    push r16
    ldi r16, OLED_READ_ADDR
    rcall i2c_send_byte

    rcall i2c_read_byte_ack
    rcall i2c_read_byte_nack

    pop r16
    rcall i2c_do_stop_condition
    ret
