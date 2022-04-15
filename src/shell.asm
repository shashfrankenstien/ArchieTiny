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
    ldi r16, 0xaa
    ldi r17, 10                                ; x1
    ldi r18, 118                               ; x2
    ldi r19, 2                                 ; y1
    ldi r20, 4                                 ; y2
    rcall oled_fill_rect                       ; fill oled with data in r16

    ; =========
    ; Hello World! :D
    ldi r16, 3
    ldi r17, 30
    rcall oled_set_cursor                      ; set cursor to start writing data

    ldi r31, hi8(hello_world)          ; Initialize Z-pointer to the start of the hello_world label
    ldi r30, lo8(hello_world)
    ldi r16, hello_world_len
    rcall oled_put_str_flash

    ; =========

    rcall i2c_lock_release
    .irp param,31,30,20,19,18,17,16
        pop r\param
    .endr
    ret






; ; wait for r9 to change.
; ; need to move off of using registers for button presses [TODO]
; shell_console:
;     rjmp _shell_console_wait

; _shell_console_sleep_wait:
;     sleep
; _shell_console_wait:
;     cpi r9, 0
;     breq _shell_console_sleep_wait

;     ; shell entered
;     rcall oled_clr_screen



hello_world:
    .ascii " Hello World "
    .equ   hello_world_len ,    . - hello_world      ; calculates the string length


.balign 2


