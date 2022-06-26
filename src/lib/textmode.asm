.include "config.inc"                                   ; TEXTMODE_CURSOR_PAGE and TEXTMODE_CURSOR_COL

; this module wraps oled and provides helper routines to print continuous text

.equ    MAX_FONT_PIXELS_PER_ROW,        (OLED_MAX_COL / FONT_WIDTH) * FONT_WIDTH        ; performs floor division

; textmode_set_cursor takes
;   - r16 - page address
;   - r17 - column address
; just stores addresses in TEXTMODE_CURSOR_PAGE and TEXTMODE_CURSOR_COL
textmode_set_cursor:
    sts TEXTMODE_CURSOR_PAGE, r16
    sts TEXTMODE_CURSOR_COL, r17
    ret


; textmode_get_cursor returns
;   - page address in r16
;   - column address in r17
textmode_get_cursor:
    lds r16, TEXTMODE_CURSOR_PAGE
    lds r17, TEXTMODE_CURSOR_COL
    ret



; textmode_put_char_internal take one character ascii value in r16
;   - this does too much. ugh! [FIXME]
textmode_put_char_internal:
    .irp param,16,17,18,19,20
        push r\param
    .endr
    mov r18, r16                               ; save char in r18

    lds r19, TEXTMODE_CURSOR_PAGE              ; save current page address in r19
    lds r20, TEXTMODE_CURSOR_COL               ; save current column address in r20

    cpi r18, '\n'
    breq _textmode_new_line

    cpi r18, '\b'
    breq _textmode_backspace

    cpi r20, MAX_FONT_PIXELS_PER_ROW           ; cap column at OLED_MAX_COL-FONT_WIDTH (ignore last column) and roll to next row (page)
    brlo _textmode_no_new_line

_textmode_new_line:
    clr r20                                    ; new column index is rolled over to 0

    inc r19                                    ; increment TEXTMODE_CURSOR_PAGE and check for overflow
    sbrc r19, 3                                ; if r19 reached 8, scroll oled down (00001000 <- test 3rd bit)
    rcall oled_scroll_page_down
    sbrc r19, 3                                ; if r19 reached 8, decrement r19 to 7 because we gonna scroll again soon
    dec r19

    mov r17, r20                               ; new column index is rolled over to 0
    mov r16, r19                               ; move new page index into r16
    rcall oled_set_relative_cursor             ; set cursor to last line
    rjmp _textmode_new_line_done

_textmode_no_new_line:
    mov r16, r19
    mov r17, r20
    rcall oled_set_relative_cursor

_textmode_new_line_done:
    cpi r18, '\n'
    breq _textmode_put_char_done

    rcall oled_io_open_write_data
    mov r16, r18
    rcall oled_io_put_char
    rcall oled_io_close

    ldi r16, FONT_WIDTH
    add r20, r16                               ; increment column index
    rjmp _textmode_put_char_done

_textmode_backspace:
    cpi r20, FONT_WIDTH                        ; new column index is rolled over to 0
    brsh _textmode_no_prev_page                ; lower cap column to 0 and roll to prev row (page)

    tst r19
    brne _textmode_no_scroll_up
    rcall oled_scroll_page_up
    rjmp _textmode_scroll_up_done

_textmode_no_scroll_up:
    dec r19

_textmode_scroll_up_done:
    ldi r20, MAX_FONT_PIXELS_PER_ROW           ; new column index is rolled back to end of previous row

_textmode_no_prev_page:
    subi r20, FONT_WIDTH                       ; decrement column index
    mov r17, r20
    mov r16, r19                               ; move new page index into r16
    rcall oled_set_relative_cursor             ; set cursor at current column (r17)

    rcall oled_io_open_write_data              ; re-open data io once cursor is updated
    ldi r16, ' '                               ; remove current character
    rcall oled_io_put_char
    rcall oled_io_close

_textmode_put_char_done:
    sts TEXTMODE_CURSOR_PAGE, r19
    sts TEXTMODE_CURSOR_COL, r20

    .irp param,20,19,18,17,16
        pop r\param
    .endr
    ret



; textmode_put_char take one character ascii value in r16
;   this is a simple wrapper routine
textmode_put_char:
    rcall i2c_rlock_acquire
    rcall textmode_put_char_internal
    rcall i2c_rlock_release
    ret


; textmode_put_char_inv take one character ascii value in r16
;   this is a simple wrapper routine
textmode_put_char_inv:
    rcall i2c_rlock_acquire
    rcall oled_color_inv_start
    rcall textmode_put_char_internal
    rcall oled_color_inv_stop
    rcall i2c_rlock_release
    ret
