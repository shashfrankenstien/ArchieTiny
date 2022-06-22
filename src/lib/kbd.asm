
; text kbd is just a single character printed with inverted colors
; one is able to scrub through all characters and either
;   - select the current character (button - TBD)
;   - remove previous character (button - TBD)
;   - complete typing and return (button - TBD)


; constants to behave as enum
.equ    KBD_OK,         0xff
.equ    KBD_CANCEL,     0xfe

; general button aliases
.equ    ENTER_BTN,          ADC_VD_CH1_BTN_0
.equ    EXIT_BTN,           ADC_VD_CH1_BTN_1
.equ    OPTIONS_BTN,        ADC_VD_CH1_BTN_2

; button aliases for nav_kbd_start
.equ    NAV_UP_BTN,         ADC_VD_CH0_BTN_0
.equ    NAV_DOWN_BTN,       ADC_VD_CH0_BTN_1
.equ    NAV_LEFT_BTN,       ADC_VD_CH0_BTN_2
.equ    NAV_RIGHT_BTN,      ADC_VD_CH0_BTN_3

; .equ    NAV_UP_BTN,         ADC_VD_CH0_BTN_2
; .equ    NAV_DOWN_BTN,       ADC_VD_CH0_BTN_3
; .equ    NAV_LEFT_BTN,       ADC_VD_CH0_BTN_1
; .equ    NAV_RIGHT_BTN,      ADC_VD_CH0_BTN_0

; button aliases for text_kbd_start
.equ    SCRUB_OK_BTN,       ADC_VD_CH0_BTN_4
.equ    SCRUB_NEXT_BTN,     ADC_VD_CH0_BTN_0
.equ    SCRUB_PREV_BTN,     ADC_VD_CH0_BTN_1
.equ    SCRUB_BACKSP_BTN,   ADC_VD_CH0_BTN_2
.equ    SCRUB_SPACE_BTN,    ADC_VD_CH0_BTN_3

; .equ    SCRUB_OK_BTN,       ADC_VD_CH0_BTN_4
; .equ    SCRUB_NEXT_BTN,     ADC_VD_CH0_BTN_2
; .equ    SCRUB_PREV_BTN,     ADC_VD_CH0_BTN_3
; .equ    SCRUB_BACKSP_BTN,   ADC_VD_CH0_BTN_1
; .equ    SCRUB_SPACE_BTN,    ADC_VD_CH0_BTN_0




; returns button presses in terms of navigation bits in r16. see SREG_ADC_VD_HLD desc in drivers/gpio.asm
;  - NAV_UP_BTN, NAV_DOWN_BTN, NAV_LEFT_BTN, NAV_RIGHT_BTN, ENTER_BTN and EXIT_BTN
nav_kbd_start:
    push r18

_nav_kbd_sleep_start:
    lds r16, SREG_GPIO_PC
    cbr r16, (1<<GPIO_BTN_0_PRS)
    sts SREG_GPIO_PC, r16                      ; clear GPIO_BTN_x_PRS

    sleep

    rcall gpio_adc_vd_btn_read                 ; ADC buttons
    tst r16
    brne _nav_kbd_done

    lds r18, SREG_GPIO_PC
    sbrs r18, GPIO_BTN_0_PRS                   ; PC INT button (only 1 button)
    rjmp _nav_kbd_sleep_start

    ldi r16, (1<<ENTER_BTN)
    rjmp _nav_kbd_done                         ; return that OK button was pressed

_nav_kbd_done:
    lds r18, SREG_GPIO_PC
    cbr r18, (1<<GPIO_BTN_0_PRS)
    sts SREG_GPIO_PC, r18                      ; clear GPIO_BTN_x_PRS

    pop r18
    ret






; accepts starting scrub character in r16
; returns selected character in r16 and any special characters / other button presses in r17
text_kbd_start:
    .irp param,18,20,21,22
        push r\param
    .endr
    clr r21                                    ; r21 will house any control characters that need be returned

    cpi r16, ' '
    brsh _text_kbd_show_scrub
    ldi r16, ' '                               ; if we receive control character (less than ' '), we replace with first character

_text_kbd_show_scrub:
    mov r20, r16                               ; r20 will track character scrubbing (scrub position)
    rcall textmode_put_char_inv                ; write initial scrub character from r16

    rcall textmode_get_cursor                  ; get and store current cursor address. this is performed after textmode_put_char_inv so that new lines are handled better
    subi r17, FONT_WIDTH                       ; subtract font width from current column to get the beginning of scrub character
    mov r22, r16                               ; store current page address in r22, column address will remain in r17


_text_kbd_sleep_start:
    lds r16, SREG_GPIO_PC
    cbr r16, (1<<GPIO_BTN_0_PRS)
    sts SREG_GPIO_PC, r16                      ; clear GPIO_BTN_x_PRS

    sleep

    rcall gpio_adc_vd_btn_read
    mov r18, r16
    tst r18
    brne _text_kbd_handle_SCRUB_OK_BTN

    lds r18, SREG_GPIO_PC
    sbrs r18, GPIO_BTN_0_PRS                   ; PC INT button (only 1 button)
    rjmp _text_kbd_sleep_start

    ldi r21, KBD_OK
    rjmp _text_kbd_done                        ; return that OK button was pressed

; ADC buttons - check each (switch case)
_text_kbd_handle_SCRUB_OK_BTN:                 ; ACTION - return current character to caller
    sbrs r18, SCRUB_OK_BTN
    rjmp _text_kbd_handle_SCRUB_NEXT_BTN

    rjmp _text_kbd_done                        ; done section will take care of returning the selected character


_text_kbd_handle_SCRUB_NEXT_BTN:               ; ACTION - scrub to next character
    sbrs r18, SCRUB_NEXT_BTN
    rjmp _text_kbd_handle_SCRUB_PREV_BTN

    inc r20                                    ; scrub to next character
    cpi r20, ' ' + FONT_LUT_SIZE               ; cap at FONT_LUT_SIZE and start over at ' '
    brlo _text_kbd_no_char_rollover
    ldi r20, ' '
_text_kbd_no_char_rollover:
    rjmp _text_kbd_scrub_overwrite_inplace


_text_kbd_handle_SCRUB_PREV_BTN:               ; ACTION - scrub to prev character
    sbrs r18, SCRUB_PREV_BTN
    rjmp _text_kbd_handle_SCRUB_SPACE_BTN

    cpi r20, ' ' + 1                           ; lower cap at ' ' and start over at FONT_LUT_SIZE
    brsh _text_kbd_no_char_rollover_rev
    ldi r20, ' ' + FONT_LUT_SIZE
_text_kbd_no_char_rollover_rev:
    dec r20                                    ; scrub to prev character
    rjmp _text_kbd_scrub_overwrite_inplace


_text_kbd_handle_SCRUB_SPACE_BTN:             ; ACTION - return space ' '
    sbrs r18, SCRUB_SPACE_BTN
    rjmp _text_kbd_handle_SCRUB_BACKSP_BTN

    ldi r21, ' '
    rjmp _text_kbd_done


_text_kbd_handle_SCRUB_BACKSP_BTN:             ; ACTION - return backspace '\b'
    sbrs r18, SCRUB_BACKSP_BTN
    rjmp _text_kbd_handle_ENTER_BTN

    mov r16, r22                               ; copy over current page index into r16. current column index is already in r17
    rcall textmode_set_cursor                  ; set cursor back to where it was before kbd was called
    ldi r16, ' '
    rcall textmode_put_char                    ; clear the kbd inverted character

    ldi r21, '\b'
    rjmp _text_kbd_done


_text_kbd_handle_ENTER_BTN:                    ; ACTION - return new line '\n'
    sbrs r18, ENTER_BTN
    rjmp _text_kbd_handle_EXIT_BTN

    mov r16, r22                               ; copy over current page index into r16. current column index is already in r17
    rcall textmode_set_cursor                  ; set cursor back to where it was before kbd was called
    ldi r16, ' '
    rcall textmode_put_char                    ; clear the kbd inverted character

    ldi r21, '\n'
    rjmp _text_kbd_done                        ; return '\n'


_text_kbd_handle_EXIT_BTN:                     ; ACTION - exit application?
    sbrs r18, EXIT_BTN
    rjmp _text_kbd_sleep_start

    ldi r21, KBD_CANCEL
    rjmp _text_kbd_done


_text_kbd_scrub_overwrite_inplace:
    mov r16, r22                               ; copy over current page index into r16. current column index is already in r17
    rcall textmode_set_cursor                  ; set cursor to start writing data

    mov r16, r20
    rcall textmode_put_char_inv

    rjmp _text_kbd_sleep_start


_text_kbd_done:
    mov r16, r22                               ; copy over current page index into r16. current column index is already in r17
    rcall textmode_set_cursor                  ; set cursor back to where it was before kbd was called

    mov r16, r20                               ; return whatever is in r20 through r16 (character at scrub position)
    mov r17, r21                               ; return whatever is in r21 through r17 (control character)
    .irp param,22,21,20,18
        pop r\param
    .endr
    ret
