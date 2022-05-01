; this module implements a command line shell using
;   - gpio.asm to read button presses and stuff
;   - sh1106.asm (oled) to display the command line shell
;
; to avoid using a lot of memory, input is directly written to oled
; then, when we see a new line character 10 (\n),
;   - we can read back the full line from the oled
;   - parsing this line can be done as a stream until we hit character 10 (\n)


hello_world:
    .ascii " Hello World "
    .equ   hello_world_len ,    . - hello_world      ; calculates the string length

.balign 2


; splash hello world on the screen
shell_splash_screen:
    .irp param,16,17,18,19,20,30,31
        push r\param
    .endr
    rcall i2c_lock_acquire

    ; =========
    ldi r16, 0x66
    ldi r17, ((127 - (FONT_WIDTH * hello_world_len) - 8) / 2)          ; x1 - position at the center with 8/2 pixels of padding on either side
    ldi r18, 127 - ((127 - (FONT_WIDTH * hello_world_len) - 8) / 2)    ; x2
    ldi r19, (3 * 8) + 5                                 ; y1
    ldi r20, (5 * 8) + 3                                ; y2
    rcall oled_fill_rect_by_pixel                       ; fill oled with data in r16

    ; =========
    ; Hello World! :D
    ldi r16, 4
    ldi r17, ((127 - (FONT_WIDTH * hello_world_len)) / 2)   ; center the hello world message
    rcall oled_set_cursor                      ; set cursor to start writing data

    ; rcall oled_color_inv_start
    ldi r31, hi8(hello_world)                  ; Initialize Z-pointer to the start of the hello_world label
    ldi r30, lo8(hello_world)
    ldi r16, hello_world_len
    rcall oled_put_str_flash
    ; rcall oled_color_inv_stop

    ; =========
    rcall i2c_lock_release

    .irp param,31,30,20,19,18,17,16
        pop r\param
    .endr
    ret



; main gui entry point
shell_home_task:
    sbi PORTB, LED_PIN
    ldi r20, 0x64                              ; power on debounce delay (0x64 = 100 ms)
    rcall timer_delay_ms_short                 ; short delay before resetting SREG_GPIO_PC at start up (need time for debouncing capacitors to charge)
    clr r22
    sts SREG_GPIO_PC, r22                      ; clear gpio button status register

    rcall shell_splash_screen
    cbi PORTB, LED_PIN

_shell_home_wait:
    sleep
    lds r22, SREG_GPIO_PC
    sbrs r22, GPIO_BTN_0_PRS
    rjmp _shell_home_wait

    rcall terminal_app_open
    rjmp _shell_home_wait
