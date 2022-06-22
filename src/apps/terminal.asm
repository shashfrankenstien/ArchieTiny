.include "config.inc"                                   ; TERMINAL_PROMPT_CHAR

; this module implements a command line terminal using
;   - lib/kbd.asm typing and reading button presses
;   - lib/textmode.asm and drivers/sh1106.asm (oled) to display the command line terminal
;
; input is simply written to oled for now
; [TODO]: once we see a new line character 10 (\n),
;   - we can read back the full line from the oled or ram
;   - parsing can be done as a stream until we hit character 10 (\n)



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

    cpi r17, KBD_OK
    breq _terminal_char_wait

    cpi r17, KBD_CANCEL
    brne _terminal_char_print

    mov r18, r16
    ldi r30, lo8(msg_ui_exit_confirm)
    ldi r31, hi8(msg_ui_exit_confirm)
    rcall ui_confirm_popup_show
    tst r16
    brne _terminal_exit
    mov r16, r18
    rjmp _terminal_char_wait

_terminal_char_print:
    clr r18
    cpse r17, r18
    mov r16, r17
    rcall textmode_put_char
    cpi r17, '\n'
    breq _terminal_prompt
    mov r16, r19
    rjmp _terminal_char_wait

_terminal_exit:

    .irp param,19,18,17,16
        pop r\param
    .endr
    ret
