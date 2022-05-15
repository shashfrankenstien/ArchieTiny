
; text kbd is just a single character printed with inverted colors
; one is able to scrub through all characters and either
;   - select the current character (button - TBD)
;   - remove previous character (button - TBD)
;   - complete typing and return (button - TBD)

; navigation kbd

.equ    NAV_UP,         0x00
.equ    NAV_DOWN,       0x01
.equ    NAV_LEFT,       0x02
.equ    NAV_RIGHT,      0x03
.equ    NAV_OK,         0xff
.equ    NAV_OPTIONS,    0xfe



; accepts starting scrub character in r16
text_kbd_start:
    .irp param,18,20,21,22
        push r\param
    .endr
    clr r21                                    ; r21 will house any control characters that need be returned

    cpi r16, ' '
    brsh _text_kbd_show_scrub
    ldi r16, ' '                               ; if we receive control character (less than ' '), we replace with first character

_text_kbd_show_scrub:
    mov r20, r16                               ; r20 will track character scrubbing
    rcall textmode_put_char_inv                ; write initial scrub character from r16

    rcall textmode_get_cursor                  ; get and store current cursor address. this is performed after textmode_put_char_inv so that new lines are handled better
    subi r17, FONT_WIDTH                       ; subtract font width from current column to get the beginning of scrub character
    mov r22, r16                               ; store current page address in r22, column address will remain in r17


_text_kbd_sleep_start:
    lds r16, SREG_GPIO_PC
    cbr r16, (1<<GPIO_BTN_0_PRS) | (1<<GPIO_BTN_1_PRS) | (1<<GPIO_BTN_2_PRS)
    sts SREG_GPIO_PC, r16                      ; clear GPIO_BTN_x_PRS

    sleep

    rcall gpio_adc_vd_btn_read
    mov r18, r16
    clr r16
    cpse r18, r16
    rjmp _text_kbd_handle_adc_btn_0

    lds r18, SREG_GPIO_PC
    clr r16
    cpse r18, r16
    rjmp _text_kbd_handle_pc_btn_0

    rjmp _text_kbd_sleep_start

; PC INT buttons
_text_kbd_handle_pc_btn_0:
    sbrs r18, GPIO_BTN_0_PRS
    rjmp _text_kbd_handle_pc_btn_1

    ldi r21, NAV_OK
    rjmp _text_kbd_done                        ; return that OK button was pressed

_text_kbd_handle_pc_btn_1:
    sbrs r18, GPIO_BTN_1_PRS
    rjmp _text_kbd_handle_pc_btn_2

    ldi r21, NAV_OPTIONS
    rjmp _text_kbd_done                        ; return that options button was pressed

_text_kbd_handle_pc_btn_2:
    sbrs r18, GPIO_BTN_2_PRS
    rjmp _text_kbd_sleep_start

    rjmp _text_kbd_sleep_start

; ADC buttons
_text_kbd_handle_adc_btn_0:                    ; check if adc btn 0 is pressed; ACTION - return new line '\n'
    sbrs r18, ADC_VD_BTN_0
    rjmp _text_kbd_handle_adc_btn_1

    mov r16, r22                               ; copy over current page index into r16. current column index is already in r17
    rcall textmode_set_cursor                  ; set cursor back to where it was before kbd was called
    ldi r16, ' '
    rcall textmode_put_char                    ; clear the kbd inverted character

    ldi r21, '\n'
    rjmp _text_kbd_done                        ; return '\n'


_text_kbd_handle_adc_btn_1:                    ; check if adc btn 1 is pressed; ACTION - scrub prev
    sbrs r18, ADC_VD_BTN_1
    rjmp _text_kbd_handle_adc_btn_2

    cpi r20, ' ' + 1                           ; lower cap at ' ' and start over at FONT_LUT_SIZE
    brsh _text_kbd_no_char_rollover_rev
    ldi r20, ' ' + FONT_LUT_SIZE
_text_kbd_no_char_rollover_rev:
    dec r20                                    ; scrub to prev character
    rjmp _text_kbd_scrub_overwrite_inplace


_text_kbd_handle_adc_btn_2:                    ; check if adc btn 2 is pressed; ACTION - scrub next
    sbrs r18, ADC_VD_BTN_2
    rjmp _text_kbd_handle_adc_btn_3

    inc r20                                    ; scrub to next character
    cpi r20, ' ' + FONT_LUT_SIZE               ; cap at FONT_LUT_SIZE and start over at ' '
    brlo _text_kbd_no_char_rollover
    ldi r20, ' '
_text_kbd_no_char_rollover:
    rjmp _text_kbd_scrub_overwrite_inplace


_text_kbd_handle_adc_btn_3:                    ; check if adc btn 3 is pressed; ACTION - return backspace '\b'
    sbrs r18, ADC_VD_BTN_3
    rjmp _text_kbd_handle_adc_btn_4

    mov r16, r22                               ; copy over current page index into r16. current column index is already in r17
    rcall textmode_set_cursor                  ; set cursor back to where it was before kbd was called
    ldi r16, ' '
    rcall textmode_put_char                    ; clear the kbd inverted character

    ldi r21, '\b'
    rjmp _text_kbd_done


_text_kbd_handle_adc_btn_4:                    ; check if adc btn 4 is pressed; ACTION - return current character
    sbrs r18, ADC_VD_BTN_4
    rjmp _text_kbd_sleep_start

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

    mov r16, r20                               ; return whatever is in r20 through r16
    mov r17, r21                               ; return whatever is in r21 through r17
    .irp param,22,21,20,18
        pop r\param
    .endr
    ret






; returns button presses in terms of navigation indications - UP, DOWN, LEFT, RIGHT
nav_kbd_start:
    .irp param,18,20,21,22
        push r\param
    .endr
    ; clr r21                                    ; r21 will house any control characters that need be returned

_nav_kbd_sleep_start:
    lds r16, SREG_GPIO_PC
    cbr r16, (1<<GPIO_BTN_0_PRS) | (1<<GPIO_BTN_1_PRS) | (1<<GPIO_BTN_2_PRS)
    sts SREG_GPIO_PC, r16                      ; clear GPIO_BTN_x_PRS

    sleep

    rcall gpio_adc_vd_btn_read
    mov r18, r16
    clr r16
    cpse r18, r16
    rjmp _nav_kbd_handle_adc_btn_0

    lds r18, SREG_GPIO_PC
    clr r16
    cpse r18, r16
    rjmp _nav_kbd_handle_pc_btn_0

    rjmp _nav_kbd_sleep_start

; PC INT buttons
_nav_kbd_handle_pc_btn_0:
    sbrs r18, GPIO_BTN_0_PRS
    rjmp _nav_kbd_handle_pc_btn_1

    ldi r16, NAV_OK
    rjmp _nav_kbd_done

_nav_kbd_handle_pc_btn_1:
    sbrs r18, GPIO_BTN_1_PRS
    rjmp _nav_kbd_handle_pc_btn_2

    rjmp _nav_kbd_sleep_start

_nav_kbd_handle_pc_btn_2:
    sbrs r18, GPIO_BTN_2_PRS
    rjmp _nav_kbd_sleep_start

    rjmp _nav_kbd_sleep_start

; ADC buttons
_nav_kbd_handle_adc_btn_0:                    ; check if adc btn 0 is pressed; ACTION - navigate up
    sbrs r18, ADC_VD_BTN_0
    rjmp _nav_kbd_handle_adc_btn_1

    ldi r16, NAV_UP
    rjmp _nav_kbd_done

_nav_kbd_handle_adc_btn_1:                    ; check if adc btn 1 is pressed; ACTION - navigate down
    sbrs r18, ADC_VD_BTN_1
    rjmp _nav_kbd_handle_adc_btn_2

    ldi r16, NAV_DOWN
    rjmp _nav_kbd_done

_nav_kbd_handle_adc_btn_2:                    ; check if adc btn 2 is pressed; ACTION - navigate left
    sbrs r18, ADC_VD_BTN_2
    rjmp _nav_kbd_handle_adc_btn_3

    ldi r16, NAV_LEFT
    rjmp _nav_kbd_done

_nav_kbd_handle_adc_btn_3:                    ; check if adc btn 3 is pressed; ACTION - navigate right
    sbrs r18, ADC_VD_BTN_3
    rjmp _nav_kbd_handle_adc_btn_4

    ldi r16, NAV_RIGHT
    rjmp _nav_kbd_done

_nav_kbd_handle_adc_btn_4:                    ; check if adc btn 4 is pressed; ACTION - navigate OK
    ; sbrs r18, ADC_VD_BTN_4
    ; rjmp _nav_kbd_sleep_start

    rjmp _nav_kbd_sleep_start

_nav_kbd_done:
    lds r18, SREG_GPIO_PC
    cbr r18, (1<<GPIO_BTN_0_PRS) | (1<<GPIO_BTN_1_PRS) | (1<<GPIO_BTN_2_PRS)
    sts SREG_GPIO_PC, r18                      ; clear GPIO_BTN_x_PRS

    .irp param,22,21,20,18
        pop r\param
    .endr
    ret
