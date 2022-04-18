
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
.equ SET_COMM_SCAN_DIR_INV,  0xc8                    ; inverted = page numbers start on the end closer to the i2c pinout

.equ SET_SEGMENT_REMAP_NORM, 0xa0                    ; column scanning direction left to right or right to left
.equ SET_SEGMENT_REMAP_INV,  0xa1                    ; reverse of SET_SEGMENT_REMAP_NORM



; SREG_OLED - oled status register (1)
;   - register holds 8 oled status flags
;   - currently only 1 bit is assigned - OLED_COLOR_INVERT
;      -------------------------------------------------------------------------------
;      |  N/A  |  N/A  |  N/A  |  N/A  |  N/A  |  N/A  |  N/A  |  OLED_COLOR_INVERT  |
;      -------------------------------------------------------------------------------
;
; OLED_COLOR_INVERT (bit 0)
;   - this flag is used to implement software color inverted mode
;   - NOTE: this is different from SET_COLOR_INV, which is an oled device function to invert the entire screen
;   - if OLED_COLOR_INVERT is set, anything written to the the oled will be inverted (1's complement with COM instruction)
;       if OLED_COLOR_INVERT is cleared, it writes without 1's complement
.equ    OLED_COLOR_INVERT,       0


; --------------------------------------------------
.equ    OLED_MAX_COL,            127                ; max column index (128 x 64)
.equ    OLED_MAX_PAGE,           7                  ; max page index (each page has 8 rows)
; --------------------------------------------------


; initialize oled and set default settings
; rotate oled 180 degrees by flipping both column and page scan directions
oled_init:
    push r16

    clr r16
    sts SREG_OLED, r16                         ; clear oled status register

    rcall i2c_do_stop_condition                ; call stop condition just in case (mostly not required)

    rcall oled_io_open_write_cmds

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

    rcall oled_io_close

    rcall oled_clr_screen

    pop r16
    ret


; ----------------- i2c wrappers ------------------

; use this routine to start a command list write transaction
oled_io_open_write_cmds:
    rcall i2c_do_start_condition

    ldi r16, OLED_WRITE_ADDR                   ; i2c communication always starts with the address + read/write flag
    rcall i2c_send_byte

    ldi r16, OLED_WRITE_CMD_LIST               ; this control byte tells the display to expect a list of commands until stop condition
    rcall i2c_send_byte
    ret


; use this routine to start a command list write transaction
oled_io_open_write_data:
    rcall i2c_do_start_condition

    ldi r16, OLED_WRITE_ADDR                   ; i2c communication always starts with the address + read/write flag
    rcall i2c_send_byte

    ldi r16, OLED_WRITE_DATA_LIST              ; this tells the device to expect a list of data bytes until stop condition
    rcall i2c_send_byte
    ret


oled_io_close:
    rcall i2c_do_stop_condition
    ret

; -------------------------------------------------


; -------------- SREG_I2C wrappers ----------------
oled_sreg_color_inv_start:
    push r16
    lds r16, SREG_OLED
    sbr r16, (1 << OLED_COLOR_INVERT)        ; set to invert color
    sts SREG_OLED, r16
    pop r16
    ret


oled_sreg_color_inv_stop:
    push r16
    lds r16, SREG_OLED
    cbr r16, (1 << OLED_COLOR_INVERT)        ; set to normal color
    sts SREG_OLED, r16
    pop r16
    ret
; -------------------------------------------------



; write all zeros onto oled
oled_clr_screen:
    .irp param,16,17,18,19,20
        push r\param
    .endr

    clr r16                                    ; fill byte = 0x00 (all 0s)
    clr r17                                    ; x1 = 0
    ldi r18, OLED_MAX_COL                      ; x2 = OLED_MAX_COL
    clr r19                                    ; y2 = 0
    ldi r20, OLED_MAX_PAGE                     ; y2 = OLED_MAX_PAGE
    rcall oled_fill_rect                       ; fill oled with data in r16

    .irp param,20,19,18,17,16
        pop r\param
    .endr
    ret



; oled_set_cursor takes
;   - r16 - page address
;   - r17 - column address
; performs set page and set column address operations
oled_set_cursor:
    .irp param,16,17,18,19
        push r\param
    .endr
    mov r19, r16

    inc r17
    inc r17                                    ; screen is somehow offset by 2 columns ?? :/

    mov r18, r17
    lsr r18
    lsr r18
    lsr r18
    lsr r18                                    ; keep high bits of column address by shifting right 4 times
    ori r18, SET_COLUMN_H                      ; set column start addr high bits

    andi r17, 0x0f                             ; keep low bits of column address
    ori r17, SET_COLUMN_L                      ; set column start addr low bits

    rcall oled_io_open_write_cmds

    mov r16, r19                               ; get current page number (in range y1 to y2)
    ori r16, SET_PAGE_ADDRESS                  ; OR with SET_PAGE_ADDRESS cmd
    rcall i2c_send_byte

    ; set cursor to precomputed column low and high commands saved in r17 and r18
    mov r16, r17
    rcall i2c_send_byte
    mov r16, r18
    rcall i2c_send_byte

    rcall oled_io_close

    .irp param,19,18,17,16
        pop r\param
    .endr
    ret



; oled_fill_rect takes 4 coordinates - x1, x2, y1, y2
; it will fill the rectangle between (x1,y1) (x1,y2) (x2,y1) (x2,y2)
; input registers -
;   r16 - byte to fill
;   r17 - x1
;   r18 - x2
;   r19 - y1
;   r20 - y2
;
; so what we've got here is that
;   x1 and x2 indicate column addresses
;   y1 and y2 indicate row addresses (this is page address resolution for now; further resolution gets complicated)
oled_fill_rect:                                ; fill rect on screen with value in r16
                                               ; r16 through r20 are inputs. calling routine should push and pop these
    .irp param,21,22,23
        push r\param
    .endr
    in r21, SREG

    ; pre calc some stuff
    mov r22, r16                               ; save away page fill byte till later because we need r16 for other stuff
    lds r16, SREG_OLED
    sbrc r16, OLED_COLOR_INVERT                ; check if needs to be inverted
    com r22                                    ; invert!

    mov r23, r17                               ; save away original x1. this needs to be loaded back for each page
    inc r18                                    ; increment x2 so that we can break the loop once x1 overflows original x2
    inc r20                                    ; increment y2 so that we can break the loop once y1 overflows original y2

_next_page:                                    ; iterate pages y1 to y2

    mov r16, r19                               ; get current page number (in range y1 to y2)
    mov r17, r23                               ; reload original x1
    rcall oled_set_cursor                      ; set cursor to start writing data

    rcall oled_io_open_write_data

_next_column:
    mov r16, r22                               ; load back the fill byte that was originally saved away
    rcall i2c_send_byte                        ; i2c_send_byte modifies r16, so we need to reload r16 at every iteration
    inc r17
    cp r17, r18
    brne _next_column

    rcall oled_io_close                        ; finished writing a page

    inc r19
    cp r19, r20
    brne _next_page

    out SREG, r21
    .irp param,23,22,21
        pop r\param
    .endr                                      ; r16 through r20 are inputs. calling routine should push and pop these
    ret                                        ; return value r16 will contain ACK from last byte transfered




; oled_io_put_char depends on a font being included. it will expect
;   - a label 'font_lut' that contains the lookup table for characters
;   - FONT_WIDTH constant which indicates how many bytes need to be written per character
;   - FONT_OFFSET constant which indicates the first ascii charater in the lookup table
;           consequent characters can be reached by incrementing by FONT_WIDTH
;
; it take one character ascii value in r16
; to write the character, we need to find the index of the character in font_lut
;   - index = addr of font_lut + ((r16 - FONT_OFFSET) * FONT_WIDTH)
;
; oled_io_put_char assumes that start condition has been signaled and cursor address is set before being called
; it also expects that the oled is in OLED_WRITE_DATA_LIST mode
oled_io_put_char:
    .irp param,17,18,19,30,31
        push r\param
    .endr
    in r18, SREG
    lds r19, SREG_OLED

    ldi r31, hi8(font_lut)          ; initialize Z-pointer to the start of the font lookup table
    ldi r30, lo8(font_lut)

    subi r16, FONT_OFFSET           ; (r16 - FONT_OFFSET) * FONT_WIDTH
    ldi r17, FONT_WIDTH
    rcall mul8                      ; output is stored in r1:r0 (character index)

    add r30, r16                    ; add the character index to Z pointer
    adc r31, r17                    ; add the character index to Z pointer

    ldi r17, FONT_WIDTH             ; load loop counter
_next_font_byte:
    lpm r16, Z+                     ; load constant from flash
                                    ; memory pointed to by Z (r31:r30)
    sbrc r19, OLED_COLOR_INVERT     ; check if needs to be inverted
    com r16                         ; invert!
    rcall i2c_send_byte
    dec r17
    brne _next_font_byte

    out SREG, r18
    .irp param,31,30,19,18,17
        pop r\param
    .endr
    ret                             ; return value r16 will contain ACK from last byte transfered




; oled_put_str_flash reads string from flash and writes to oled
; it expects
;   - Z pointer set at the start of the string
;   - string length passed in r16
oled_put_str_flash:
    push r17
    push r18
    in r17, SREG
    mov r18, r16                                ; initialize loop counter with string length

    rcall oled_io_open_write_data               ; this tells the device to expect a list of data bytes until stop condition

_next_char:
    lpm r16, Z+                     ; load character from flash memory
                                    ; memory pointed to by Z (r31:r30)
    rcall oled_io_put_char
    dec r18
    brne _next_char

    rcall oled_io_close

    out SREG, r17
    pop r18
    pop r17
    ret                             ; return value r16 will contain ACK from last byte transfered



; oled_put_binary_digits converts r16 to is and 0s and writes to oled
oled_put_binary_digits:
    .irp param,17,18,19,20
        push r\param
    .endr

    in r17, SREG
    mov r18, r16                               ; save r16 for later

    rcall oled_io_open_write_data               ; this tells the device to expect a list of data bytes until stop condition

    ldi r19, 8
    ldi r20, 48
_next_bin_char:
    clr r16
    lsl r18
    rol r16
    add r16, r20
    rcall oled_io_put_char
    dec r19
    brne _next_bin_char

    rcall oled_io_close

    out SREG, r17
    .irp param,20,19,18,17
        pop r\param
    .endr
    ret                             ; return value r16 will contain ACK from last byte transfered






; test_oled_read:
;     push r16
;     rcall i2c_do_start_condition

;     ldi r16, OLED_READ_ADDR
;     rcall i2c_send_byte

;     rcall i2c_read_byte_ack
;     rcall i2c_read_byte_nack

;     rcall i2c_do_stop_condition
;     pop r16
;     ret
