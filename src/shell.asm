; this module implements a command line shell using
;   - gpio.asm to read button presses and stuff
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






; wait for any pin change interrupt to be triggered.
shell_console_task:
    sbi PORTB, LED_PIN
    ldi r20, 0x32                              ; power on debounce delay (0x32 = 50 ms)
    rcall time_delay_ms_short                  ; short delay before resetting SREG_GPIO_PC at start up (need time for debouncing capacitors to charge)
    clr r22
    sts SREG_GPIO_PC, r22                      ; clear gpio button status register
    cbi PORTB, LED_PIN

    clr r23                                    ; use r23 as a sort of status register
    clr r17                                    ; r17 will track the current column index incase we need to go back
    clr r18                                    ; r18 will track the current page index
    clr r19                                    ; r19 will track scroll position
    ldi r20, ' '                               ; r20 will handle character scrubbing

    rjmp _shell_console_wait

_shell_btn_clr_sleep_wait:
    cli
    lds r22, SREG_GPIO_PC
    cbr r22, (1<<GPIO_BTN_0_PRS) | (1<<GPIO_BTN_1_PRS) | (1<<GPIO_BTN_2_PRS)
    sts SREG_GPIO_PC, r22                      ; clear GPIO_BTN_0_PRS
    sei
_shell_console_sleep_wait:
    sleep
_shell_console_wait:
    cli
    lds r22, SREG_GPIO_PC
    cpi r22, 0
    sei
    breq _shell_console_sleep_wait

    sbrc r23, 0                                 ; if bit 0 is cleared, start console
    rjmp _shell_handle_btn_0

    ; console entered
    rcall i2c_lock_acquire
    rcall oled_clr_screen

    clr r16                                    ; oled_set_cursor expects page index in r16. start shell at page 0
    rcall oled_set_cursor                      ; set cursor to start writing data

    rcall oled_io_open_write_data
    ldi r16, '>'
    rcall oled_io_put_char
    ldi r16, ' '
    rcall oled_io_put_char

    rcall oled_sreg_color_inv_start
    mov r16, r20
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
    mov r16, r18                               ; copy over current page index into r16. current column index is already in r17
    rcall oled_set_cursor                      ; set cursor to start writing data

    rcall oled_io_open_write_data
    mov r16, r20                               ; confirm current character
    rcall oled_io_put_char

    ldi r16, FONT_WIDTH
    add r17, r16                               ; increment column index
    cpi r17, OLED_MAX_COL - FONT_WIDTH         ; cap column at OLED_MAX_COL-FONT_WIDTH (ignore last column) and roll to next row (page)
    brlo _shell_no_next_page

    rcall oled_io_close                        ; close data io so that we can change the cursor
    inc r18                                    ; go to next row (page)
    sbrc r18, 3                                ; if r18 reached 8, reset it to 0 (00001000 <- test 3rd bit)
    clr r18
    inc r19                                    ; next check scroll position
    sbrc r19, 3                                ; if r19 reached 8, scroll oled down (00001000 <- test 3rd bit)
    rcall oled_scroll_text_down
    sbrc r19, 3                                ; if r19 reached 8, decrement r19 because we gonna scroll again soon (00001000 <- test 3rd bit)
    dec r19

    clr r17                                    ; new column index is rolled over to 0
    mov r16, r18                               ; move new page index into r16
    rcall oled_set_cursor_wipe_eol             ; set cursor and wipe till end of line from current column (r17)

    rcall oled_io_open_write_data              ; re-open data io

_shell_no_next_page:
    rcall oled_sreg_color_inv_start
    mov r16, r20
    rcall oled_io_put_char
    rcall oled_sreg_color_inv_stop

    rcall oled_io_close
    rcall i2c_lock_release


_shell_handle_btn_1:
    sbrs r22, GPIO_BTN_1_PRS
    rjmp _shell_handle_btn_2

    inc r20                                    ; scrub to next character
    cpi r20, ' ' + FONT_LUT_SIZE               ; cap at FONT_LUT_SIZE and start over at ' '
    brlo _shell_no_char_rollover
    ldi r20, ' '
_shell_no_char_rollover:

    rcall i2c_lock_acquire
    mov r16, r18                               ; copy over current page index into r16. current column index is already in r17
    rcall oled_set_cursor                      ; set cursor to start writing data

    rcall oled_io_open_write_data
    rcall oled_sreg_color_inv_start
    mov r16, r20
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


