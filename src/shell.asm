; this module implements a command line shell using
;   - gpio.asm to read button presses and scrubbing
;   - sh1106.asm (oled) to display the command line shell
;
; to avoid using a lot of memory, input is directly written to oled
; then, when we see a new line character 10 (\n),
;   - we can read back the full line from the oled
;   - parsing this line can be done as a stream until we hit character 10 (\n)


; splash hello world on the screen
shell_splash_screen:
    .irp param,16,17,18,19,20,30,31
        push r\param
    .endr
    rcall i2c_lock_acquire

    ; =========
    ldi r16, 0x99
    ldi r17, ((127 - (FONT_WIDTH * hello_world_len) - 8) / 2)          ; x1 - position at the center with 8 pixels of padding on either side
    ldi r18, 127 - ((127 - (FONT_WIDTH * hello_world_len) - 8) / 2)    ; x2
    ldi r19, 2                                 ; y1
    ldi r20, 4                                 ; y2
    rcall oled_fill_rect                       ; fill oled with data in r16

    ; =========
    ; Hello World! :D
    ldi r16, 3
    ldi r17, ((127 - (FONT_WIDTH * hello_world_len)) / 2)   ; center the hello world message
    rcall oled_set_cursor                      ; set cursor to start writing data

    rcall oled_sreg_color_inv_start
    ldi r31, hi8(hello_world)                  ; Initialize Z-pointer to the start of the hello_world label
    ldi r30, lo8(hello_world)
    ldi r16, hello_world_len
    rcall oled_put_str_flash
    rcall oled_sreg_color_inv_stop

    ; =========

    rcall i2c_lock_release

    .irp param,31,30,20,19,18,17,16
        pop r\param
    .endr
    ret






; wait for GPIO_BTN_0_PRS to change.
shell_console_task:
    clr r23                                    ; use r23 as a sor of status register
    clr r17                                    ; r17 will track the current column index incase we need to go back
    ldi r18, ' '                               ; r18 will handle character scrubbing

    ldi r20, 0x05                              ; power on debounce
    rcall time_delay_ms_short                  ; short delay before resetting SREG_GPIO at start up (need to allow debouncing capacitors to charge)
    clr r16
    sts SREG_GPIO, r16                         ; clear gpio button status register
    rjmp _shell_console_wait

_shell_btn_clr_sleep_wait:
    cli
    lds r22, SREG_GPIO
    cbr r22, (1<<GPIO_BTN_0_PRS) | (1<<GPIO_BTN_1_PRS) | (1<<GPIO_BTN_2_PRS)
    sts SREG_GPIO, r22                          ; clear GPIO_BTN_0_PRS
    sei
_shell_console_sleep_wait:
    sleep
_shell_console_wait:
    cli
    lds r22, SREG_GPIO
    andi r22, 0b00000111                        ; check only last 3 bits (for any button press)
    cpi r22, 0
    sei
    breq _shell_console_sleep_wait

    sbrc r23, 0
    rjmp _shell_handle_btn_0

    ; shell entered
    rcall i2c_lock_acquire
    rcall oled_clr_screen

    clr r16
    rcall oled_set_cursor                      ; set cursor to start writing data

    rcall oled_io_open_write_data
    ldi r16, '>'
    rcall oled_io_put_char
    ldi r16, ' '
    rcall oled_io_put_char

    rcall oled_sreg_color_inv_start
    mov r16, r18
    rcall oled_io_put_char
    rcall oled_sreg_color_inv_stop

    rcall oled_io_close
    rcall i2c_lock_release

    sbr r23, (1<<0)                             ; flag that shell has been entered. next btn press will go to _shell_check_btn_0

    ldi r16, FONT_WIDTH * 2
    add r17, r16

    rjmp _shell_btn_clr_sleep_wait

_shell_handle_btn_0:
    sbrs r22, GPIO_BTN_0_PRS
    rjmp _shell_handle_btn_1

    rcall i2c_lock_acquire
    clr r16
    rcall oled_set_cursor                      ; set cursor to start writing data

    rcall oled_io_open_write_data
    mov r16, r18
    rcall oled_io_put_char
    rcall oled_sreg_color_inv_start
    mov r16, r18
    rcall oled_io_put_char
    rcall oled_sreg_color_inv_stop

    rcall oled_io_close
    rcall i2c_lock_release

    ldi r16, FONT_WIDTH
    add r17, r16
    ; TODO: need to cap r17 at 127 and go to next row (page)

_shell_handle_btn_1:
    sbrs r22, GPIO_BTN_1_PRS
    rjmp _shell_handle_btn_2

    inc r18                                    ; scrub to next character
    cpi r18, ' ' + FONT_LUT_SIZE                     ; cap at FONT_LUT_SIZE and start over at ' '
    brlo _shell_char_no_rollover
    ldi r18, ' '

_shell_char_no_rollover:

    rcall i2c_lock_acquire
    clr r16
    rcall oled_set_cursor                      ; set cursor to start writing data

    rcall oled_io_open_write_data
    rcall oled_sreg_color_inv_start
    mov r16, r18
    rcall oled_io_put_char
    rcall oled_sreg_color_inv_stop

    rcall oled_io_close
    rcall i2c_lock_release

_shell_handle_btn_2:
    sbrs r22, GPIO_BTN_2_PRS
    rjmp _shell_handle_btn_done


_shell_handle_btn_done:
    rjmp _shell_btn_clr_sleep_wait



hello_world:
    .ascii " Hello World "
    .equ   hello_world_len ,    . - hello_world      ; calculates the string length


.balign 2


