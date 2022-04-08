
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
.equ SET_DISPLY_OFF,         0xae                    ; 0b1010111x
.equ SET_DISPLY_ON,          0xaf                    ; where x is 1 for ON and 0 for OFF

.equ SET_PAGE_ADDRESS,       0xb0                    ; 0b10110xxx where xxx are page addresses 0 - 7
.equ SET_COLUMN_L,           0x00                    ; 0b0000xxxx where xxxx are column number low bits
.equ SET_COLUMN_H,           0x10                    ; 0b0001xxxx where xxxx are column number high bits

.equ SET_DISP_FREQ_MODE,     0xd5                    ; double command. use with DEFAULT_DISP_FREQ
.equ DEFAULT_DISP_FREQ,      0x50

.equ SET_COLOR_NORM,         0xa6                    ; normal = white fg, black bg
.equ SET_COLOR_INV,          0xa7                    ; inverted = black fg, white bg

.equ SET_COMM_SCAN_DIR_NORM, 0xc0                    ; normal = page numbers start on the end away from the i2c pinout
.equ SET_COMM_SCAN_DIR_INV,  0xc8                    ; inverted =  page numbers start on the end closer to the i2c pinout

.equ SET_SEGMENT_REMAP_NORM, 0xa0                    ; column scanning direction left to right or right to left
.equ SET_SEGMENT_REMAP_INV,  0xa1                    ; reverse of SET_SEGMENT_REMAP_NORM



oled_init:
    .irp param,16,17,18,19,20
        push r\param
    .endr

    rcall i2c_do_stop_condition                ; call stop condition just in case (mostly not required)
    rcall i2c_do_start_condition

    ldi r16, OLED_WRITE_ADDR                   ; i2c communication always starts with the address + read/write flag
    rcall i2c_send_byte

    ldi r16, OLED_WRITE_CMD_LIST               ; this control byte tells the display to expect a list of commands until stop condition
    rcall i2c_send_byte

    ldi r16, SET_DISPLY_ON                     ; turn on the display
    rcall i2c_send_byte
    ldi r16, SET_DISP_FREQ_MODE                ; set the display refresh rate (double command)
    rcall i2c_send_byte
    ldi r16, DEFAULT_DISP_FREQ
    rcall i2c_send_byte

    ldi r16, SET_COMM_SCAN_DIR_INV             ; flip the screen
    rcall i2c_send_byte
    ldi r16, SET_SEGMENT_REMAP_INV             ; reverse the column scan direction
    rcall i2c_send_byte

    rcall i2c_do_stop_condition

    clr r16                                    ; fill byte = 0x00
    clr r17                                    ; x1 = 0
    ldi r18, 127                               ; x2 = 127
    clr r19                                    ; y2 = 0
    ldi r20, 7                                 ; y2 = 7
    rcall oled_fill_rect                            ; fill oled with data in r16 (all 0s)

    .irp param,20,19,18,17,16
        pop r\param
    .endr
    ret



; oled_fill_rect takes 4 coordinates - x1, x2, y1, y2
; it will fill the rectangle between (x1,y1) (x1,y2) (x2,y1) (x2,y2)
; registers used -
;   r16 - byte to fill
;   r17 - x1
;   r18 - x2
;   r19 - y1
;   r20 - y2
;
; so what we've got here is that
;   x1 and x2 indicate column addresses
;   y1 and y2 indicate row addresses (page address can be derived from this, but it gets complicated)

oled_fill_rect:                                ; fill rect on screen with value in r16
                                               ; r16 through r20 are inputs. calling routine should push and pop these
    .irp param,13,14,15,21,22
        push r\param
    .endr
    in r15, SREG

    ; pre calc some stuff
    mov r14, r17                               ; save away original x1. this needs to be loaded back for each page
    inc r18                                    ; increment x2 so that we can break the loop once x1 overflows original x2
    inc r20                                    ; increment y2 so that we can break the loop once y1 overflows original y2

    inc r17
    inc r17                                    ; screen is somehow offset by 2 columns ?? :/
    mov r21, r17
    andi r21, 0x0f                             ; keep low bits of x1
    ori r21, SET_COLUMN_L                      ; set column start addr low bits

    mov r22, r17
    lsr r22
    lsr r22
    lsr r22
    lsr r22                                    ; keep high bits of x1 by shifting right 4 times
    ori r22, SET_COLUMN_H                      ; set column start addr high bits

    mov r13, r16                               ; save away page fill byte till later because we need r16

_next_page:                                    ; iterate pages y1 to y2
    rcall i2c_do_stop_condition
    rcall i2c_do_start_condition

    ldi r16, OLED_WRITE_ADDR
    rcall i2c_send_byte

    ldi r16, OLED_WRITE_CMD
    rcall i2c_send_byte
    mov r16, r19                               ; get current page number (in range y1 to y2)
    ori r16, SET_PAGE_ADDRESS                  ; OR with SET_PAGE_ADDRESS cmd
    rcall i2c_send_byte

    ; set cursor to precomputed x1 low and high saved in r21 and r22
    ldi r16, OLED_WRITE_CMD
    rcall i2c_send_byte
    mov r16, r21
    rcall i2c_send_byte

    ldi r16, OLED_WRITE_CMD
    rcall i2c_send_byte
    mov r16, r22
    rcall i2c_send_byte

    ldi r16, OLED_WRITE_DATA_LIST              ; this tells the device to expect a list of data bytes until stop condition
    rcall i2c_send_byte

    mov r17, r14                               ; load original x2
_next_column:
    mov r16, r13                               ; load back fill byte that was originally saved away
    rcall i2c_send_byte                        ; i2c_send_byte modifies r16, so we need to reload r16 at every iteration
    inc r17
    cp r17, r18
    brne _next_column

    inc r19
    cp r19, r20
    brne _next_page

    rcall i2c_do_stop_condition

    out SREG, r15
    .irp param,22,21,15,14,13
        pop r\param
    .endr                                      ; r16 through r20 are inputs. calling routine should push and pop these
    ret                                        ; return value r16 will contain ACK from last byte transfered








test_oled:
    .irp param,16,17,18,19,20
        push r\param
    .endr

    ; ldi r16, 0b00110011                        ; oled fill byte = 0b00110011
    ldi r17, 30                                ; x1
    ldi r18, 90                                ; x2
    ldi r19, 2                                 ; y1
    ldi r20, 5                                 ; y2
    rcall oled_fill_rect                       ; fill oled with data in r16

    sbrs r16, 0
    cbi PORTB, 1

    .irp param,20,19,18,17,16
        pop r\param
    .endr
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
