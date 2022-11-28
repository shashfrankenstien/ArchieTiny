; this module implements the main user interface shell


shell_splash_msg:
    .ascii " Archie Tiny v0.1 \0"
    .equ   shell_splash_msg_len ,    . - shell_splash_msg      ; calculates the string length

.balign 2


; splash hello world on the screen
shell_splash_screen:
    .irp param,16,17,18,19,20,30,31
        push r\param
    .endr
    rcall i2c_rlock_acquire
    rcall oled_clr_screen

    ; =========
    ldi r16, 0x99
    ldi r17, ((OLED_MAX_COL - (FONT_WIDTH * shell_splash_msg_len) - 8) / 2)          ; x1 - position at the center with 8/2 pixels of padding on either side
    ldi r18, OLED_MAX_COL - ((OLED_MAX_COL - (FONT_WIDTH * shell_splash_msg_len) - 8) / 2)    ; x2
    ldi r19, (1 * 8) + 6                            ; y1
    ldi r20, (5 * 8) + 2                            ; y2
    rcall oled_fill_rect                            ; fill oled with data in r16

    ; =========
    ; Hello World! :D
    ldi r16, 3
    ldi r17, ((OLED_MAX_COL - (FONT_WIDTH * shell_splash_msg_len)) / 2) + 2   ; center the hello world message. +2 to account for some rounding error
    rcall oled_set_cursor                           ; set cursor to start writing data

    rcall oled_color_inv_start
    ldi r31, hi8(shell_splash_msg)                  ; Initialize Z-pointer to the start of the shell_splash_msg label
    ldi r30, lo8(shell_splash_msg)
    rcall oled_print_flash
    rcall oled_color_inv_stop

    ; =========
    rcall i2c_rlock_release

    buzzer_macro_play_melody 100 D6 1 G6 1 E6 1 C7 1 B7 2

_shell_splash_wait:                                 ; wait for button press and exit
    sleep
    lds r16, SREG_GPIO_PC
    sbrs r16, GPIO_BTN_0_PRS
    rjmp _shell_splash_wait

    .irp param,31,30,20,19,18,17,16
        pop r\param
    .endr
    ret








; describes menu label list to display
; passed to ui_menu_show routine
shell_menu_apps_list:
    .asciz "splash"                            ; index 0
    .asciz "terminal"                          ; index 1
    .asciz "file manager"                      ; index 2
    .asciz "settings"                          ; index 3
    .asciz "scan i2c"                          ; index 4
    .asciz "malloc 2"                          ; index 5
    .asciz "fs test"                           ; index 6
    .asciz "fs format"                         ; index 7
    .asciz "fram test"                         ; index 8
    .asciz "fram write"                        ; index 9
    .byte 0                                    ; end of list

.balign 2



; main gui entry point
shell_home_task:
    sbi PORTB, BUZZER_PIN
    ldi r20, 0x32                              ; power on debounce delay (0x32 = 50 ms)
    rcall timer_delay_ms_short                 ; short delay before resetting SREG_GPIO_PC at start up (need time for debouncing capacitors to charge)
    clr r20
    sts SREG_GPIO_PC, r20                      ; clear gpio button status register
    cbi PORTB, BUZZER_PIN

    rcall shell_splash_screen
    sts SREG_GPIO_PC, r20                      ; clear gpio button status register again

    clr r16                                    ; first item in menu selected (0 indexed)
    clr r17                                    ; menu scroll position top
_shell_home_show_menu:
    ldi r18, (1<<ENTER_BTN)                    ; register ENTER_BTN action
    ldi r24, lo8(shell_menu_apps_list)
    ldi r25, hi8(shell_menu_apps_list)
    ldi r30, lo8(pm(ui_menu_print_flash_item_cb))
    ldi r31, hi8(pm(ui_menu_print_flash_item_cb))
    rcall ui_menu_show                         ; show apps menu
                                               ; let user select from shell_menu_apps_list list. rcall appropriate routine using selected index

_shell_home_menu_0:
    cpi r16, 0
    brne _shell_home_menu_1
    rcall shell_splash_screen
    rjmp _shell_home_show_menu                 ; show menu after running selected option

_shell_home_menu_1:
    cpi r16, 1
    brne _shell_home_menu_2
    rcall terminal_app_open
    rjmp _shell_home_show_menu                 ; show menu after running selected option

_shell_home_menu_2:
    cpi r16, 2
    brne _shell_home_menu_3
    rcall fm_app_open
    rjmp _shell_home_show_menu                 ; show menu after running selected option

_shell_home_menu_3:
    cpi r16, 3
    brne _shell_home_menu_4
    rcall settings_app_open
    rjmp _shell_home_show_menu                 ; show menu after running selected option

_shell_home_menu_4:
    cpi r16, 4
    brne _shell_home_menu_5
    rcall shell_i2c_scanner
    rjmp _shell_home_show_menu                 ; show menu after running selected option

_shell_home_menu_5:
    cpi r16, 5
    brne _shell_home_menu_6
    ldi r30, lo8(shell_menu_apps_list)         ; show first entry in shell_menu_apps_list as popup
    ldi r31, hi8(shell_menu_apps_list)
    rcall ui_alert_popup_show

    rjmp _shell_home_show_menu                 ; show menu after running selected option

_shell_home_menu_6:
    cpi r16, 6
    brne _shell_home_menu_7
    rcall fs_test_print
    rjmp _shell_home_show_menu                 ; show menu after running selected option

_shell_home_menu_7:
    cpi r16, 7
    brne _shell_home_menu_8
    rcall fs_format
    rjmp _shell_home_show_menu                 ; show menu after running selected option

_shell_home_menu_8:
    cpi r16, 8
    brne _shell_home_menu_9
    rcall fram_test_print
    rjmp _shell_home_show_menu                 ; show menu after running selected option

_shell_home_menu_9:
    cpi r16, 9
    brne _shell_home_menu_done
    rcall fram_test_write
    ; rjmp _shell_home_show_menu                 ; show menu after running selected option

_shell_home_menu_done:
    rjmp _shell_home_show_menu                 ; show menu after running selected option









shell_i2c_scanner:
    push r16
    push r17

    clr r16
    clr r17
    rcall i2c_rlock_acquire

    rcall oled_clr_screen
    rcall oled_set_cursor

    ldi r16, 0x77                               ; 0x78 - 0x7f are only for PCA9685. ignoring this because mb85rc64 is ACKing 0x7c???? :/
_shell_i2c_scanner_next:
    mov r17, r16
    lsl r16
    rcall i2c_do_start_condition
    rcall i2c_send_byte
    rcall i2c_do_stop_condition

    lsr r16                                     ; ACK bit is moved into carry flag -> carry is cleared on successful ACK
    brcs _shell_i2c_scanner_noprint

    mov r16, r17
    rcall oled_print_hex_digits
    rcall oled_io_open_write_data               ; this tells the device to expect a list of data bytes until stop condition
    ldi r16, ' '
    rcall oled_io_put_char
    rcall oled_io_close

_shell_i2c_scanner_noprint:
    mov r16, r17
    dec r16
    brne _shell_i2c_scanner_next

    rcall i2c_rlock_release
_shell_i2c_scanner_wait:                        ; wait for button press and exit
    sleep
    rcall nav_kbd_start

    sbrs r16, ENTER_BTN                         ; if enter button is pressed, skip the next statement
    rjmp _shell_i2c_scanner_wait

    pop r17
    pop r16
    ret






fs_test_print:
    .irp param,16,17,18,19,24,25
        push r\param
    .endr

    clr r24                    ; load address low byte into register pair r25:r24
    clr r25                    ; load address high byte into register pair r25:r24

_fs_test_next_section:
    rcall i2c_rlock_acquire
    rcall oled_clr_screen

    clr r16
_fs_test_next_line:
    clr r17
    rcall oled_set_cursor

    ldi r18, 8
_fs_test_next:
    mov r19, r16
    rcall fs_wrapper_read
    rcall oled_print_hex_digits
    mov r16, r19
    adiw r24, 1
    dec r18
    brne _fs_test_next

    inc r16
    cpi r16, OLED_MAX_PAGE + 1
    brlo _fs_test_next_line

    rcall i2c_rlock_release

_fs_test_wait:                            ; wait for button press and exit
    sleep
    rcall nav_kbd_start

    sbrc r16, NAV_DOWN_BTN                ; if down button is not pressed, skip the next statement
    rjmp _fs_test_next_section

    sbrs r16, ENTER_BTN                   ; if enter button is pressed, skip the next statement
    rjmp _fs_test_wait

    .irp param,25,24,19,18,17,16
        pop r\param
    .endr
    ret






fram_test_write:
    .irp param,16,17,24,25
        push r\param
    .endr

    clr r24                    ; load address low byte into register pair r25:r24
    clr r25                    ; load address high byte into register pair r25:r24

    rcall i2c_rlock_acquire
    rcall fram_io_open_writer
    ldi r17, 25

_fram_test_write_next:
    clr r16
    rcall i2c_send_byte
    dec r17
    brne _fram_test_write_next

    rcall fram_io_close
    rcall i2c_rlock_release

    .irp param,25,24,17,16
        pop r\param
    .endr
    ret




fram_test_print:
    .irp param,16,17,18,19,24,25
        push r\param
    .endr

    clr r24                    ; load address low byte into register pair r25:r24
    clr r25                    ; load address high byte into register pair r25:r24

_fram_test_next_section:
    rcall i2c_rlock_acquire
    rcall oled_clr_screen
    rcall i2c_rlock_release

    clr r16
_fram_test_next_line:
    clr r17
    rcall i2c_rlock_acquire
    rcall oled_set_cursor

    mov r19, r16
    ldi r18, 8                  ; read 7 bytes with ack and last one with nack
_fram_test_next:
    rcall fram_io_open_reader
    rcall i2c_read_byte_nack
    rcall fram_io_close
    rcall oled_print_hex_digits
    adiw r24, 1
    dec r18
    brne _fram_test_next

    rcall i2c_rlock_release
    mov r16, r19
    inc r16
    cpi r16, OLED_MAX_PAGE + 1
    brlo _fram_test_next_line


_fram_test_wait:                          ; wait for button press and exit
    sleep
    rcall nav_kbd_start


    sbrc r16, NAV_DOWN_BTN                ; if down button is not pressed, skip the next statement
    rjmp _fram_test_next_section

    sbrs r16, ENTER_BTN                   ; if enter button is pressed, skip the next statement
    rjmp _fram_test_wait

    .irp param,25,24,19,18,17,16
        pop r\param
    .endr
    ret
