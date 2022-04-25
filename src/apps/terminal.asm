.include "config.inc"                                   ; TERMINAL_PROMPT_CHAR


terminal_app_open:
    .irp param,16,17,18,19
        push r\param
    .endr

    ; console entered
    rcall i2c_lock_acquire
    rcall oled_clr_screen
    rcall i2c_lock_release

    clr r16                                    ; textmode_set_cursor expects page index in r16 and column index in r17. start shell at 0,0
    clr r17
    rcall textmode_set_cursor                      ; set cursor to start writing data

_terminal_prompt:
    ldi r16, TERMINAL_PROMPT_CHAR
    rcall textmode_put_char
    ldi r16, ' '
    rcall textmode_put_char

    ldi r16, 'a'
_terminal_char_wait:
    rcall text_kbd_start
    mov r19, r16
    clr r18
    cpse r17, r18
    mov r16, r17
    rcall textmode_put_char
    cpi r17, '\n'
    breq _terminal_prompt
    mov r16, r19
    rjmp _terminal_char_wait
