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
; passed to shell_show_menu routine
shell_apps_menu:
    .ascii "splash\0"                          ; index 0
    .ascii "another splash\0"                  ; index 1
    .ascii "terminal\0"                        ; index 2
    .byte 0                                    ; end of list

.balign 2



; main gui entry point
shell_home_task:
    sbi PORTB, LED_PIN
    ldi r20, 0x64                              ; power on debounce delay (0x64 = 100 ms)
    rcall timer_delay_ms_short                 ; short delay before resetting SREG_GPIO_PC at start up (need time for debouncing capacitors to charge)
    clr r22
    sts SREG_GPIO_PC, r22                      ; clear gpio button status register
    cbi PORTB, LED_PIN

    rcall shell_splash_screen
    sts SREG_GPIO_PC, r22                      ; clear gpio button status register again

_shell_home_show_menu:
    ldi r30, lo8(shell_apps_menu)
    ldi r31, hi8(shell_apps_menu)
    rcall shell_show_menu                      ; show apps menu
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

    rjmp _shell_home_show_menu                 ; show menu after running selected app






; takes address to the menu item names list in Z pointer
; returns the selected index out of the menu items in r16
shell_show_menu:
    .irp param,17,18,19,20,21
        push r\param
    .endr

    clr r20                                     ; r20 keeps count of total number of items in the menu
    clr r17                                     ; r17 is the start column address. this can be offset?
    ldi r18, OLED_MAX_COL                       ; r18 is the end column address for highlighting. this can be offset too!
    clr r19                                     ; r19 at this point indicates that the nav cursor is on the first item by default
    clr r20                                     ; r20 contains previous nav cursor.
                                                ;       if this is different from r19, highlight operation is performed

    rcall i2c_lock_acquire
    rcall oled_clr_screen

_show_menu_next:
    mov r16, r20                                ; move page (row) address from r20 into t16. r17 already points to start column
    rcall oled_set_relative_cursor              ; set cursor to start writing data

    rcall oled_print_flash                      ; print one entry from the list (until \0 is encountered)
    inc r20

    lpm r16, Z                                  ; peek next byte to check if we reached the end of list
    tst r16
    brne _show_menu_next

    rcall oled_invert_inplace_page_row          ; highlight (invert) the first item by default. this can be better handled by changing r19
    rcall i2c_lock_release

_show_menu_navigate:
    cp r19, r21                                 ; check if prev selection is same as current. if it is same, skip highlight operation
    breq _show_menu_nav_check

    rcall i2c_lock_acquire
    mov r16, r19                                ; save new item number
    mov r19, r21
    rcall oled_invert_inplace_page_row          ; uninvert prev item
    mov r19, r16                                ; restore new item number
    mov r21, r16                                ; update prev item number tracker
    rcall oled_invert_inplace_page_row          ; invert!
    rcall i2c_lock_release

_show_menu_nav_check:
    rcall nav_kbd_start                         ; start the navigation keyboard
                                                ;   for now, we only care about UP, DOWN and OK presses
    cpi r16, NAV_UP
    brne _show_menu_nav_check_down              ; if nav is not UP, continue to check DOWN

    cpi r19, 0                                  ; move selection up. if top is reached, roll over to the bottom
    brne .+2
    mov r19, r20
    dec r19
    rjmp _show_menu_navigate

_show_menu_nav_check_down:
    cpi r16, NAV_DOWN
    brne _show_menu_nav_check_ok                ; if nav is not DOWN, continue to check OK

    inc r19                                     ; move selection down. if bottom is reached, roll over to the top
    cpse r19, r20
    rjmp _show_menu_navigate
    clr r19
    rjmp _show_menu_navigate

_show_menu_nav_check_ok:
    cpi r16, NAV_OK
    brne _show_menu_navigate                    ; if nav is not OK, go back and start over

    mov r16, r19                                ; if OK is pressed, return current selected item index to calling routine

    .irp param,21,20,19,18,17
        pop r\param
    .endr
    ret
