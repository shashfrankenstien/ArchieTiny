; this file implements a bunch of ui components
;   - menu
;   - confirm window

; ------------------------------------------------------------------------------------------------

.equ    UI_MENU_HOR_PADDING,        15          ; menu padding in pixels
.equ    UI_MENU_BORDER_OFFSET,      2



.equ    UI_POPUP_WINDOW_CHAR_WIDTH,   8                                                       ; 8 text characters
.equ    UI_POPUP_WINDOW_WIDTH,        (FONT_WIDTH * UI_POPUP_WINDOW_CHAR_WIDTH)               ; 8 text characters
.equ    UI_POPUP_WINDOW_HEIGHT,       2                                                       ; 2 rows (pages)

.equ    UI_POPUP_START_COL,           (MAX_FONT_PIXELS_PER_ROW - UI_POPUP_WINDOW_WIDTH) / 2
.equ    UI_POPUP_START_PAGE,          3

.equ    UI_POPUP_YN_CHAR_WIDTH,       6                                                       ; cant be changed. this is hard coded to => " Y  N "
.equ    UI_POPUP_YN_PADDING,          ((UI_POPUP_WINDOW_CHAR_WIDTH - UI_POPUP_YN_CHAR_WIDTH) / 2) * FONT_WIDTH   ; Y/N blocks are totally 6 characters wide

.equ    UI_POPUP_OK_PADDING,          4


; ------------------------------------------------------------------------------------------------
; reusable scrollable menu component
;
; ui_menu_show uses a callback function passed in Z pointer
; the callback function should:
;   - take pointer to menu in r25:r24
;   - take the index of the menu item in r16 and print 1 item at current cursor
;   - return 0 in r16 if index is out of menu bounds
;   - return 0 in r16 if the last item was reached and printed. else return whatever
;
; a menu from flash might use r25:r24 to point to zero terminated menu item list in flash
; a menu from file system (directory listing) might pass pointer to directory in r25:r24
;
; so,
; ui_menu_show takes:
;   - address to the menu in r25:r24 pair
;   - address to the callback function in r31:r30 pair (Z)
;   - also previous selected item index in r16 and previous scroll position in r17 (state recall values)
; returns the selected index out of the menu items in r16; and current scroll position in r17
;
; workflow:
;   - setup variable registers and clear screen
;   - set r16 to the item index and use icall to print one item from the menu
;   - repeat until
;       - icall returns 0 in r16 (set bit 0 in the flags variable register to indicate end of menu was reached)
;       - screen is full (OLED_MAX_PAGE number of items have been printed on screen)
;
;   - use scrolling if more than OLED_MAX_PAGE items exist in the menu (described separately below) - max menu length is 256??
;
;   - use bit 1 of the flags register to indicate if the nav cursor has been highlighted
;
;   - enable controls - UP, DOWN, OK using nav_kbd_start
;       - move the nav cursor and handle scrolling as required using UP and DOWN actions
;       - on OK action, return the item number selected by the nav cursor in r16
;           also return current scroll position in r17 - menu can be recalled back to the previous state by passing back r16 and r17
;
; scrolling:
;   - scroll down action:
;       - to print the next menu item, jump all the way back to _ui_menu_next, set r16 and print next item with icall
;       - each scroll down action will only result in one additional item being printed
;
;   - scroll up action:
;       - once we scroll up, to find the item that needs to be printed, we use current scroll position register (r23)
;        - just as before, set r16 and print item with icall
ui_menu_show:
    .irp param,18,19,20,21,22,23
        push r\param
    .endr

    clr r20                                     ; flags register - end of menu reached flag, row highlighted flag
    mov r21, r16                                ; r21 contains the current item number that the nav cursor is on
    clr r22                                     ; r22 contains previous nav cursor item number.
                                                ;       if this is different from r21, highlight operation is performed
    mov r23, r17                                ; scroll position tracker

    ldi r17, UI_MENU_HOR_PADDING                ; r17 is the start column address. this can be offset?
    ldi r18, OLED_MAX_COL - UI_MENU_HOR_PADDING ; r18 is the end column address for highlighting. this can be offset too!
    clr r19                                     ; r19 indicates the page (row) number the nav cursor is on (0 by default)

    rcall i2c_lock_acquire
    rcall oled_clr_screen
    rcall i2c_lock_release

_ui_menu_next:
    mov r16, r19                                ; move page (row) address from r19 into t16. r17 already points to start column
    rcall oled_lock_acquire                     ; routine pointed by Z can acquire i2c lock internally, but oled lock is held externally to maintain oled cursor position
    rcall i2c_lock_acquire
    rcall oled_set_relative_cursor              ; set cursor to start writing data
    rcall i2c_lock_release

    mov r16, r19
    add r16, r23
    icall                                       ; call routine pointed to by r31:r30 (Z)
    rcall oled_lock_release

    tst r16                                     ; peek next byte to check if we reached the end of list
    breq _ui_menu_last_item_shown

    cpi r19, OLED_MAX_PAGE                      ; check if we reached the end of the screen
    breq _ui_menu_navigate

    inc r19
    rjmp _ui_menu_next

; ------ this section is only used when scrolling up
_ui_menu_scroll_prev:
    cbr r20, (1<<0)                             ; remove end of menu flag since while scrolling up, we're most likely not showing end of menu anymore

    clr r16
    rcall oled_lock_acquire                     ; routine pointed by Z can acquire i2c lock internally, but oled lock is held externally to maintain oled cursor position
    rcall i2c_lock_acquire
    rcall oled_set_relative_cursor              ; set cursor to start writing data
    rcall i2c_lock_release

    clr r16
    add r16, r23
    icall                                       ; call routine pointed to by r31:r30 (Z)
    rcall oled_lock_release

    rjmp _ui_menu_navigate
; ------

_ui_menu_last_item_shown:
    sbr r20, (1<<0)                             ; flag that end of menu reached

_ui_menu_navigate:
    sbrs r20, 1                                 ; check if any row is highlighted
    rjmp _ui_menu_navigate_highlight            ; if nothing is highlighted, jump to highlight operation

    cp r21, r22                                 ; check if prev selection is same as current. if it is same, skip highlight operation
    breq _ui_menu_nav_check

    mov r19, r22
    sub r19, r23
    rcall i2c_lock_acquire
    rcall oled_invert_inplace_relative_page_row ; uninvert prev item using r19
    rcall i2c_lock_release
_ui_menu_navigate_highlight:
    mov r22, r21                                ; update prev item number tracker with new number
    mov r19, r21
    sub r19, r23
    rcall i2c_lock_acquire
    rcall oled_invert_inplace_relative_page_row ; invert using r19!
    rcall i2c_lock_release
    sbr r20, (1<<1)                             ; flag that a row is currently highlighted

_ui_menu_nav_check:
    rcall nav_kbd_start                         ; start the navigation keyboard
                                                ;   for now, we only care about UP, DOWN and OK presses
    cpi r16, NAV_UP
    brne _ui_menu_nav_check_down                ; if nav is not UP, continue to check DOWN

    mov r16, r21
    sub r16, r23
    tst r16                                     ; if top not reached, move selection up and jump back to _ui_menu_navigate
    brne _ui_menu_nav_move_up

    ; check scroll up
    tst r23                                     ; top reached - check if scroll up is required
    breq _ui_menu_navigate                      ; if scroll up not required, we've reached the top of the menu

    ; scroll up
    dec r21                                     ; move current selection up
    dec r23                                     ; indicate that scroll up is performed
    rcall i2c_lock_acquire
    rcall oled_scroll_page_up
    rcall i2c_lock_release
    rjmp _ui_menu_scroll_prev

_ui_menu_nav_move_up:
    dec r21                                     ; move current selection up
    rjmp _ui_menu_navigate


_ui_menu_nav_check_down:
    cpi r16, NAV_DOWN
    brne _ui_menu_nav_check_ok                  ; if nav is not DOWN, continue to check OK

    inc r21                                     ; move selection down
    mov r16, r21
    sub r16, r23

    cpi r16, OLED_MAX_PAGE + 1                  ; check if scroll down is required
    brne _ui_menu_navigate                      ; scroll not required

    sbrc r20, 0                                 ; if bottom of menu is reached, set selection back (essentially do nothing)
    dec r21
    sbrc r20, 0
    rjmp _ui_menu_navigate

    ; scroll
    inc r23                                     ; scroll down to next item
    rcall i2c_lock_acquire
    rcall oled_scroll_page_down
    rcall i2c_lock_release
    rjmp _ui_menu_next                          ; jump all the way back to print the next item


_ui_menu_nav_check_ok:
    cpi r16, KBD_OK
    brne _ui_menu_navigate                      ; if nav is not OK, go back and start over

    mov r16, r21                                ; if OK is pressed, return current selected item index to calling routine
    mov r17, r23                                ; also return current scroll position
                                                ; menu can be recalled back to the previous state by passing back r16 and r17
_ui_menu_done:
    .irp param,23,22,21,20,19,18
        pop r\param
    .endr
    ret






; the ui module defines a callback routine to print an item from menu defined in flash
;   - takes pointer to menu in r25:r24
;   - takes the index of the menu item in r16 and print 1 item at current cursor
;   - returns 0 in r16 if index is out of menu bounds
;   - returns 0 in r16 if the last item was reached and printed. else return whatever
ui_menu_print_flash_item_cb:
    push r17
    push r18
    push r30
    push r31

    mov r30, r24
    mov r31, r25

    tst r16                                         ; if n (r16) is 0, no adjustment to Z required
    breq _ui_menu_print_flash_print_Z

    ldi r18, 0xff                                   ; start char counter at -1
_ui_menu_print_flash_goto_n:
    inc r18
    lpm r17, Z+
    tst r17
    brne _ui_menu_print_flash_goto_n

    tst r18                                         ; if we encounter a 0, r18 will be 0
    breq _ui_menu_print_flash_failed
    dec r16
    brne _ui_menu_print_flash_goto_n

_ui_menu_print_flash_print_Z:
    rcall oled_io_open_write_data
    rcall oled_print_flash                      ; print one entry from the list pointed by Z pointer (until \0 is encountered)
    rcall oled_io_close

    lpm r16, Z                                  ; peek next byte to check if we reached the end of list
    rjmp _ui_menu_print_flash_done

_ui_menu_print_flash_failed:
    clr r16

_ui_menu_print_flash_done:
    pop r31
    pop r30
    pop r18
    pop r17
    ret




; ------------------------------------------------------------------------------------------------
str_ui_confirm_popup_YN:
    .asciz " Y "
    .asciz " N "

str_ui_alert_popup_OK:
    .asciz " OK "

.balign 2


; reusable confirm y/n popup component
; takes address to the confirm message in Z pointer
; should be limited to UI_POPUP_WINDOW_CHAR_WIDTH characters
; returns Y/N in r16 as 0xff/0x00
ui_confirm_popup_show:
    .irp param,17,18,19
        push r\param
    .endr

    rcall internal_ui_popup_util_save_screen
    mov r19, r16                                ; save memory pointer

    ; -----------------
    rcall internal_ui_display_popup_frame

    rcall i2c_lock_acquire
    ldi r16, UI_POPUP_START_PAGE + 1                                              ; next row
    ldi r17, UI_POPUP_START_COL + UI_POPUP_YN_PADDING
    rcall oled_set_relative_cursor

    ldi r30, lo8(str_ui_confirm_popup_YN)
    ldi r31, hi8(str_ui_confirm_popup_YN)
    rcall oled_print_flash                                                  ; print Y

    rcall oled_color_inv_start                                              ; show as selected by default
    rcall oled_print_flash                                                  ; print N
    rcall oled_color_inv_stop

    rcall i2c_lock_release
    rcall internal_ui_display_popup_bottom_border

    ; -----------------

    rcall internal_ui_confirm_util_toggle_yn            ; start the navigation keyboard (blocking)
    mov r18, r16

    mov r16, r19                                ; restore screen from memory pointer
    rcall internal_ui_popup_util_restore_screen

    mov r16, r18                                ; return Y/N in r16

    .irp param,19,18,17
        pop r\param
    .endr
    ret




; reusable alert popup component - only 1 button (OK)
; takes address to the alert message in Z pointer
; should be limited to UI_POPUP_WINDOW_CHAR_WIDTH characters
ui_alert_popup_show:
    .irp param,16,17,18,19
        push r\param
    .endr

    rcall internal_ui_popup_util_save_screen
    mov r19, r16                                ; save memory pointer

    ; -----------------
    rcall internal_ui_display_popup_frame

    rcall i2c_lock_acquire
    ldi r16, UI_POPUP_START_PAGE + 1                                              ; next row
    ldi r17, UI_POPUP_START_COL + (UI_POPUP_WINDOW_WIDTH / 2) - UI_POPUP_OK_PADDING
    rcall oled_set_relative_cursor

    ldi r30, lo8(str_ui_alert_popup_OK)
    ldi r31, hi8(str_ui_alert_popup_OK)

    rcall oled_color_inv_start                                              ; show as selected by default
    rcall oled_print_flash                                                  ; print OK
    rcall oled_color_inv_stop

    rcall i2c_lock_release
    rcall internal_ui_display_popup_bottom_border

    ; -----------------

_ui_alert_wait:
    rcall nav_kbd_start                         ; start the navigation keyboard (blocking)
    cpi r16, KBD_OK
    brne _ui_alert_wait

    mov r16, r19                                ; restore screen from memory pointer
    rcall internal_ui_popup_util_restore_screen

    .irp param,19,18,17,16
        pop r\param
    .endr
    ret





; reusable input popup component - UI_POPUP_WINDOW_CHAR_WIDTH allowed characters
; takes address to the input prompt message in Z pointer
; should be limited to UI_POPUP_WINDOW_CHAR_WIDTH characters
ui_input_popup_show:
    .irp param,16,17,18,19,20
        push r\param
    .endr

    rcall internal_ui_popup_util_save_screen
    mov r19, r16                                ; save memory pointer

    ; -----------------
    rcall internal_ui_display_popup_frame

    ldi r16, UI_POPUP_START_PAGE + 1                                              ; next row
    ldi r17, UI_POPUP_START_COL + 1
    rcall textmode_set_cursor
    ; -----------------

    ldi r16, 7
    mov r18, r16
    rcall mem_alloc
    mov r20, r16                                 ; save mem pointer to be used later

    ldi r16, 'a'
_ui_input_wait:
    rcall internal_ui_display_popup_bottom_border
    rcall text_kbd_start                         ; start the navigation keyboard (blocking)
    cpi r17, KBD_OK
    breq _ui_input_done
    cpi r17, '\n'
    breq _ui_input_done
    cpi r17, KBD_CANCEL
    breq _ui_input_cancelled

    tst r18
    breq _ui_input_wait

    rcall textmode_put_char
    mov r17, r16
    mov r16, r20
    rcall mem_store
    rcall mem_pointer_inc
    mov r20, r16
    mov r16, r17
    dec r18
    brne _ui_input_wait

_ui_input_end_wait:
    rcall nav_kbd_start                         ; start the navigation keyboard (blocking)
    cpi r16, KBD_OK
    breq _ui_input_done
    cpi r16, KBD_CANCEL
    breq _ui_input_cancelled

    rjmp _ui_input_end_wait

_ui_input_cancelled:
    mov r16, r20
    rcall mem_free
    ldi r20, 0xff                               ; load cancelled code

_ui_input_done:
    mov r16, r19                                ; restore screen from memory pointer
    rcall internal_ui_popup_util_restore_screen

    mov r16, r20
    .irp param,20,19,18,17,16
        pop r\param
    .endr
    ret




; ----------------------------------------------------------
; utilities

; this utility routine saves bytes from screen into dynamic ram
; returns pointer to this data in r16
internal_ui_popup_util_save_screen:
    .irp param,17,18,19,20,21
        push r\param
    .endr

    ldi r16, UI_POPUP_WINDOW_WIDTH * UI_POPUP_WINDOW_HEIGHT
    rcall mem_alloc
    mov r19, r16                                ; save memory pointer
    mov r20, r16                                ; save writing pointer to be returned later

    ldi r21, UI_POPUP_WINDOW_HEIGHT             ; read UI_POPUP_WINDOW_HEIGHT rows worth of data

    ldi r16, UI_POPUP_START_PAGE
    ldi r17, UI_POPUP_START_COL

    rcall i2c_lock_acquire
_ui_popup_util_read_next_row:
    push r16
    push r17
    rcall oled_set_relative_cursor              ; set cursor to start reading screen data to save in ram

    rcall oled_io_open_read_data
    ldi r18, UI_POPUP_WINDOW_WIDTH - 1          ; loop only n-1 times since last read needs to end with i2c_read_byte_nack
_ui_popup_util_read_loop:
    rcall i2c_read_byte_ack                     ; read 1 byte into r16
    mov r17, r16
    mov r16, r19
    rcall mem_store                             ; store the 1 byte (r17) in memory
    rcall mem_pointer_inc
    mov r19, r16
    dec r18
    brne _ui_popup_util_read_loop
    rcall i2c_read_byte_nack                    ; read last byte from screen and store in memory
    mov r17, r16
    mov r16, r19
    rcall mem_store
    rcall mem_pointer_inc
    mov r19, r16
    rcall oled_io_close

    pop r17
    pop r16
    inc r16
    dec r21
    brne _ui_popup_util_read_next_row

    rcall i2c_lock_release
    mov r16, r20                                ; return pointer in r16

    .irp param,21,20,19,18,17
        pop r\param
    .endr
    ret





; this utility routine restores bytes from dynamic ram onto the screen
; accepts pointer to this data in r16
internal_ui_popup_util_restore_screen:
    .irp param,17,18,19,20,21
        push r\param
    .endr
    mov r19, r16                                ; save memory pointer
    mov r20, r16                                ; save memory pointer

    ldi r21, UI_POPUP_WINDOW_HEIGHT             ; write UI_POPUP_WINDOW_HEIGHT rows worth of data

    ldi r16, UI_POPUP_START_PAGE
    ldi r17, UI_POPUP_START_COL

    rcall i2c_lock_acquire
_ui_popup_util_write_next_row:
    push r16
    push r17
    rcall oled_set_relative_cursor              ; set cursor to start writing back data from ram to screen

    rcall oled_io_open_write_data
    ldi r18, UI_POPUP_WINDOW_WIDTH
_ui_popup_util_write_loop:
    mov r16, r19
    rcall mem_load
    rcall mem_pointer_inc
    mov r19, r16
    mov r16, r17
    rcall i2c_send_byte
    dec r18
    brne _ui_popup_util_write_loop
    rcall oled_io_close

    pop r17
    pop r16
    inc r16
    dec r21
    brne _ui_popup_util_write_next_row

    rcall i2c_lock_release

    mov r16, r20                                ; restore memory pointer
    rcall mem_free                              ; release memory

    .irp param,21,20,19,18,17
        pop r\param
    .endr
    ret





; calls nav_kbd_start and waits till KBD_OK is pressed. any other presses will trigger Y/N toggle
; starts with default at 'N'
internal_ui_confirm_util_toggle_yn:
    .irp param,17,18,19,20
        push r\param
    .endr
    clr r20

_ui_confirm_util_toggle_yn_kbd:
    rcall nav_kbd_start                         ; start the navigation keyboard (blocking)

    cpi r16, KBD_OK
    breq _ui_confirm_util_toggle_yn_done

    rcall i2c_lock_acquire
    ldi r17, UI_POPUP_START_COL + UI_POPUP_YN_PADDING
    ldi r18, UI_POPUP_START_COL + UI_POPUP_YN_PADDING + (UI_POPUP_YN_CHAR_WIDTH * FONT_WIDTH) - 1   ; -1 because ugh.
    ldi r19, UI_POPUP_START_PAGE + 1
    rcall oled_invert_inplace_relative_page_row
    rcall i2c_lock_release

    rcall internal_ui_display_popup_bottom_border

    com r20

    rjmp _ui_confirm_util_toggle_yn_kbd

_ui_confirm_util_toggle_yn_done:
    mov r16, r20
    .irp param,20,19,18,17
        pop r\param
    .endr
    ret









; display popup frame formatted as required
; takes address to the alert message in Z pointer. this is printed on the first line
internal_ui_display_popup_frame:
    push r16
    push r17
    push r18

    rcall i2c_lock_acquire

    ldi r16, UI_POPUP_START_PAGE
    ldi r17, UI_POPUP_START_COL
    rcall oled_set_relative_cursor

    rcall oled_io_open_write_data
    ldi r16, 0xff
    rcall i2c_send_byte
    rcall oled_io_close

    rcall oled_print_flash
    ldi r17, FONT_WIDTH
    rcall mul8
    mov r17, r16

    rcall oled_io_open_write_data
_ui_display_popup_frame_blanks0:
    clr r16
    rcall i2c_send_byte
    inc r17
    cpi r17, UI_POPUP_WINDOW_WIDTH - 2
    brlo _ui_display_popup_frame_blanks0
    rcall oled_io_close

    ldi r16, UI_POPUP_START_PAGE
    ldi r17, UI_POPUP_START_COL + UI_POPUP_WINDOW_WIDTH - 1
    rcall oled_set_relative_cursor

    rcall oled_io_open_write_data
    ldi r16, 0xff
    rcall i2c_send_byte
    rcall oled_io_close

    ; ---------------
    ldi r16, UI_POPUP_START_PAGE + 1                                              ; next row
    ldi r17, UI_POPUP_START_COL
    rcall oled_set_relative_cursor

    rcall oled_io_open_write_data
    ldi r16, 0xff
    rcall i2c_send_byte

    ldi r17, UI_POPUP_WINDOW_WIDTH - 2                                            ; float Ok button to the right with left padding
_ui_display_popup_frame_blanks1:
    clr r16
    rcall i2c_send_byte
    dec r17
    brne _ui_display_popup_frame_blanks1

    ldi r16, 0xff
    rcall i2c_send_byte
    rcall oled_io_close

    ; ---------------
    ldi r18, UI_POPUP_START_COL + UI_POPUP_WINDOW_WIDTH
    ldi r17, UI_POPUP_START_COL
    ldi r16, (UI_POPUP_START_PAGE * 8)
    rcall oled_draw_h_line_overlay

    rcall i2c_lock_release
    pop r18
    pop r17
    pop r16
    ret



internal_ui_display_popup_bottom_border:
    push r16
    push r17
    push r18
    rcall i2c_lock_acquire

    ldi r18, UI_POPUP_START_COL + UI_POPUP_WINDOW_WIDTH
    ldi r17, UI_POPUP_START_COL
    ldi r16, ((UI_POPUP_START_PAGE + UI_POPUP_WINDOW_HEIGHT) * 8) - 1
    rcall oled_draw_h_line_overlay

    rcall i2c_lock_release
    pop r18
    pop r17
    pop r16
    ret
