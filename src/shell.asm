; this module implements a command line shell using
;   - gpio.asm to read button presses and stuff
;   - sh1106.asm (oled) to display the command line shell
;
; to avoid using a lot of memory, input is directly written to oled
; then, when we see a new line character 10 (\n),
;   - we can read back the full line from the oled
;   - parsing this line can be done as a stream until we hit character 10 (\n)


hello_world:
    .ascii " Hello World \0"
    .equ   hello_world_len ,    . - hello_world      ; calculates the string length

.balign 2


; splash hello world on the screen
shell_splash_screen:
    .irp param,16,17,18,19,20,30,31
        push r\param
    .endr
    rcall i2c_lock_acquire
    rcall oled_clr_screen

    ; =========
    ldi r16, 0x66
    ldi r17, ((OLED_MAX_COL - (FONT_WIDTH * hello_world_len) - 8) / 2)          ; x1 - position at the center with 8/2 pixels of padding on either side
    ldi r18, OLED_MAX_COL - ((OLED_MAX_COL - (FONT_WIDTH * hello_world_len) - 8) / 2)    ; x2
    ldi r19, (2 * 8) + 5                                ; y1
    ldi r20, (4 * 8) + 3                                ; y2
    rcall oled_fill_rect_by_pixel                       ; fill oled with data in r16

    ; =========
    ; Hello World! :D
    ldi r16, 3
    ldi r17, ((OLED_MAX_COL - (FONT_WIDTH * hello_world_len)) / 2) + 2   ; center the hello world message. +2 to account for some rounding error
    rcall oled_set_cursor                      ; set cursor to start writing data

    rcall oled_color_inv_start
    ldi r31, hi8(hello_world)                  ; Initialize Z-pointer to the start of the hello_world label
    ldi r30, lo8(hello_world)
    rcall oled_print_flash
    rcall oled_color_inv_stop

    ; =========
    rcall i2c_lock_release

_shell_splash_wait:                            ; wait for button press and exit
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
shell_apps_menu:
    .asciz "splash"                            ; index 0
    .asciz "another splash"                    ; index 1
    .asciz "terminal"                          ; index 2
    .asciz "malloc test"                       ; index 3
    .asciz "malloc test1"                       ; index 3
    .asciz "malloc test2"                       ; index 3
    .asciz "malloc test3"                       ; index 3
    .asciz "malloc test4"                       ; index 3
    .asciz "malloc test5"                       ; index 3
    .byte 0                                    ; end of list

.balign 2



; main gui entry point
shell_home_task:
    sbi PORTB, LED_PIN
    ldi r20, 0x32                              ; power on debounce delay (0x32 = 50 ms)
    rcall timer_delay_ms_short                 ; short delay before resetting SREG_GPIO_PC at start up (need time for debouncing capacitors to charge)
    clr r22
    sts SREG_GPIO_PC, r22                      ; clear gpio button status register
    cbi PORTB, LED_PIN

    rcall shell_splash_screen
    sts SREG_GPIO_PC, r22                      ; clear gpio button status register again

_shell_home_show_menu:
    ldi r30, lo8(shell_apps_menu)
    ldi r31, hi8(shell_apps_menu)
    rcall ui_menu_show                         ; show apps menu
                                               ; let user select from shell_apps_menu list. rcall appropriate routine using selected index
    cpi r16, 0
    brne .+2
    rcall shell_splash_screen

    cpi r16, 1
    brne .+2
    rcall shell_splash_screen

    cpi r16, 2
    brne .+2
    rcall terminal_app_open

    cpi r16, 3
    brne .+2
    rcall ui_confirm_window

    rjmp _shell_home_show_menu                 ; show menu after running selected app

