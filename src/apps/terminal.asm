.include "config.inc"                                   ; TERMINAL_PROMPT_CHAR



terminal_exit_confirm_msg:
    .asciz " Exit?"

.balign 2




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
    rcall textmode_set_cursor                  ; set cursor to start writing data

_terminal_prompt:
    ldi r16, TERMINAL_PROMPT_CHAR
    rcall textmode_put_char
    ldi r16, ' '
    rcall textmode_put_char

    ldi r16, 'a'
_terminal_char_wait:
    rcall text_kbd_start
    mov r19, r16

    cpi r17, NAV_OK
    breq _terminal_char_wait

    cpi r17, NAV_OPTIONS
    breq _terminal_confirm_exit

    clr r18
    cpse r17, r18
    mov r16, r17
    rcall textmode_put_char
    cpi r17, '\n'
    breq _terminal_prompt
    mov r16, r19
    rjmp _terminal_char_wait

_terminal_confirm_exit:
    ldi r30, lo8(terminal_exit_confirm_msg)
    ldi r31, hi8(terminal_exit_confirm_msg)
    rcall ui_confirm_popup_show

    tst r16
    breq _terminal_char_wait

    .irp param,19,18,17,16
        pop r\param
    .endr
    ret
