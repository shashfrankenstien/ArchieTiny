; this file implements a bunch of ui components
;   - menu
;   - confirm window

; ------------------------------------------------------------------------------------------------

.equ    UI_MENU_HOR_PADDING,        15          ; menu padding in pixels
.equ    UI_MENU_BORDER_OFFSET,      2



; ------------------------------------------------------------------------------------------------
; utilities

; print one entry from the list pointed by Z pointer (until \0 is encountered)
; also add any fancy borders and stuff as required
_ui_menu_util_print_item_from_Z:
    push r16
    push r17
    push r18
    push r19

    mov r19, r16
    subi r17, UI_MENU_BORDER_OFFSET             ; move r17 back for border offset

    rcall i2c_lock_acquire
    rcall oled_set_relative_cursor              ; set cursor to start writing data

    ; left border
    rcall oled_io_open_write_data
    ldi r16, 0xff                               ; vertical line
    rcall i2c_send_byte
    clr r16
    rcall i2c_send_byte
    clr r16
    rcall i2c_send_byte
    rcall oled_io_close

    rcall oled_print_flash                      ; print one entry from the list pointed by Z pointer (until \0 is encountered)

    mov r16, r19
    mov r17, r18
    rcall oled_set_relative_cursor              ; set cursor to start writing data
    ; right border
    rcall oled_io_open_write_data
    clr r16
    rcall i2c_send_byte
    clr r16
    rcall i2c_send_byte
    ldi r16, 0xff                               ; vertical line
    rcall i2c_send_byte
    rcall oled_io_close

    rcall i2c_lock_release

    pop r19
    pop r18
    pop r17
    pop r16
    ret


; helper routine to move Z pointer up by 1 menu item
; NOTE: this will fail if called when Z is on the first menu item. will return Z unchanged
_ui_menu_util_Z_previous_item:
    push r16
    push r17

    ldi r17, 1

    sub r30, r17
    sbc r31, 0

    lpm r16, Z
    tst r16
    brne _ui_menu_util_Z_prev_done

_ui_menu_util_Z_prev_continue:
    sub r30, r17
    sbc r31, 0

    lpm r16, Z
    tst r16
    brne _ui_menu_util_Z_prev_continue

_ui_menu_util_Z_prev_done:
    adiw r30, 1
    pop r17
    pop r16
    ret




; helper routine to move Z pointer down by n (r16) menu items
; keeps incrementing Z until n '\0' characters were encountered
_ui_menu_util_Z_next_nth_item:
    tst r16                                         ; if n (r16) is 0, no adjustment to Z required
    breq _ui_menu_util_Z_next_nth_done

    push r17
_ui_menu_util_Z_next_nth_continue:
    lpm r17, Z+
    tst r17
    brne _ui_menu_util_Z_next_nth_continue

    dec r16
    brne _ui_menu_util_Z_next_nth_continue

    pop r17
_ui_menu_util_Z_next_nth_done:
    ret




; ------------------------------------------------------------------------------------------------

; reusable scrollable menu component
; takes address to the menu item names list in Z pointer
; returns the selected index out of the menu items in r16
; workflow:
;   - setup variable registers and clear screen
;   - use _ui_menu_util_print_item_from_Z to print one item from the menu. This leaves Z pointer in the beginning of the next item
;   - repeat until
;       - next item starts with 0 (set bit 0 in the flags variable register to indicate end of menu was reached)
;       - screen is full (OLED_MAX_PAGE number of items have been printed on screen)
;
;   - use scrolling if more than OLED_MAX_PAGE items exist in the menu (described separately below) - max menu length is 256??
;
;   - use bit 1 of the flags register to indicate if the nav cursor has been highlighted
;
;   - enable controls - UP, DOWN, OK using nav_kbd_start
;       - move the nav cursor and handle scrolling as required using UP and DOWN actions
;       - on OK action, return the item number selected by the nav cursor in r16
;
; scrolling:
;   - scrolling assumes that the Z pointer is pointing to the item just below the screen (required by scroll down action)
;
;   - scroll down action:
;       - to print the next menu item, jump all the way back to _ui_menu_next and print next item with _ui_menu_util_print_item_from_Z
;       - each scroll down action will only result in one additional item being printed
;
;   - scroll up action:
;       - to ensure scroll down is not disrupted, while scrolling up, we also move the current Z pointer using _ui_menu_util_Z_previous_item
;       - we then save this Z pointer - (Z1)
;       - once we scroll up, to find the item that needs to be printed,
;           we need to search starting from the first item of the menu and reading as many '\0' as the current item selected by the nav cursor
;           this is done using _ui_menu_util_Z_next_nth_item helper routine where n is the current nav cursor
ui_menu_show:
    .irp param,17,18,19,20,21,22,23,24,25
        push r\param
    .endr

    ldi r17, UI_MENU_HOR_PADDING                ; r17 is the start column address. this can be offset?
    ldi r18, OLED_MAX_COL - UI_MENU_HOR_PADDING ; r18 is the end column address for highlighting. this can be offset too!
    clr r19                                     ; r19 indicates the page (row) number the nav cursor is on (0 by default)

    clr r20                                     ; flags register - end of menu reached flag, row highlighted flag
    clr r21                                     ; r21 contains the current item number that the nav cursor is on
    clr r22                                     ; r22 contains previous nav cursor item number.
                                                ;       if this is different from r21, highlight operation is performed
    clr r23                                     ; scroll position tracker

    mov r24, r30                                ; save input Z pointer value in r25:r24 (first menu item)
    mov r25, r31

    rcall i2c_lock_acquire
    rcall oled_clr_screen
    rcall i2c_lock_release

_ui_menu_next:
    mov r16, r19                                ; move page (row) address from r19 into t16. r17 already points to start column
    rcall _ui_menu_util_print_item_from_Z

    lpm r16, Z                                  ; peek next byte to check if we reached the end of list
    tst r16
    breq _ui_menu_last_item_shown

    cpi r19, OLED_MAX_PAGE                      ; check if we reached the end of the screen
    breq _ui_menu_navigate

    inc r19
    rjmp _ui_menu_next

; ------ this section is only used when scrolling up
_ui_menu_scroll_prev:
    cbr r20, (1<<0)                             ; remove end of menu flag since while scrolling up, we're most likely not showing end of menu anymore
    rcall _ui_menu_util_Z_previous_item         ; move current Z pointer back to previous item (this is the bottom of the display)

    ; start at the beginning of the menu and print r21 indexed item on the top row
    push r30
    push r31

    mov r30, r24                                ; reload original Z pointer (first menu item)
    mov r31, r25

    mov r16, r21
    rcall _ui_menu_util_Z_next_nth_item         ; move Z pointer to the new cursor index (r21)

    mov r16, r21
    sub r16, r23                                ; calculate cursor page to print the item. column is already in r17
    rcall _ui_menu_util_print_item_from_Z

    pop r31
    pop r30
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
    cpi r16, NAV_OK
    brne _ui_menu_navigate                      ; if nav is not OK, go back and start over

    mov r16, r21                                ; if OK is pressed, return current selected item index to calling routine

    .irp param,25,24,23,22,21,20,19,18,17
        pop r\param
    .endr
    ret



; ------------------------------------------------------------------------------------------------

.equ    UI_CONFIRM_WINDOW_CHAR_WIDTH,   8                                                       ; 8 text characters
.equ    UI_CONFIRM_WINDOW_WIDTH,        (FONT_WIDTH * UI_CONFIRM_WINDOW_CHAR_WIDTH)             ; 8 text characters
.equ    UI_CONFIRM_WINDOW_HEIGHT,       2                                                       ; 2 rows (pages)
.equ    UI_CONFIRM_START_COL,           (MAX_FONT_PIXELS_PER_ROW - UI_CONFIRM_WINDOW_WIDTH) / 2
.equ    UI_CONFIRM_START_PAGE,          3



_ui_confirm_util_display_popup:
    ldi r16, UI_CONFIRM_START_PAGE
    ldi r17, UI_CONFIRM_START_COL
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
_ui_confirm_util_blanks0:
    clr r16
    rcall i2c_send_byte
    inc r17
    cpi r17, UI_CONFIRM_WINDOW_WIDTH - 2
    brlo _ui_confirm_util_blanks0
    rcall oled_io_close

    ldi r16, UI_CONFIRM_START_PAGE
    ldi r17, UI_CONFIRM_START_COL + UI_CONFIRM_WINDOW_WIDTH - 1
    rcall oled_set_relative_cursor

    rcall oled_io_open_write_data
    ldi r16, 0xff
    rcall i2c_send_byte
    rcall oled_io_close

    ; ---------------
    ldi r16, UI_CONFIRM_START_PAGE + 1
    ldi r17, UI_CONFIRM_START_COL
    rcall oled_set_relative_cursor

    rcall oled_io_open_write_data
    ldi r16, 0xff
    rcall i2c_send_byte

    ldi r17, FONT_WIDTH - 1
_ui_confirm_util_blanks1:
    clr r16
    rcall i2c_send_byte
    dec r17
    brne _ui_confirm_util_blanks1

    ldi r16, ' '
    rcall oled_io_put_char
    ldi r16, 'Y'
    rcall oled_io_put_char
    ldi r16, ' '
    rcall oled_io_put_char

    rcall oled_color_inv_start
    ldi r16, ' '
    rcall oled_io_put_char
    ldi r16, 'N'
    rcall oled_io_put_char
    ldi r16, ' '
    rcall oled_io_put_char
    rcall oled_color_inv_stop

    ldi r17, FONT_WIDTH - 1
_ui_confirm_util_blanks2:
    clr r16
    rcall i2c_send_byte
    dec r17
    brne _ui_confirm_util_blanks2

    ldi r16, 0xff
    rcall i2c_send_byte

    rcall oled_io_close

    ; ---------------
    ldi r18, UI_CONFIRM_START_COL + UI_CONFIRM_WINDOW_WIDTH
    ldi r17, UI_CONFIRM_START_COL
    ldi r16, (UI_CONFIRM_START_PAGE * 8)
    rcall oled_draw_h_line_overlay

    ldi r16, ((UI_CONFIRM_START_PAGE + UI_CONFIRM_WINDOW_HEIGHT) * 8) - 1
    rcall oled_draw_h_line_overlay
    ret




; reusable confirm y/n popup component
; takes address to the confirm message in Z pointer
; should be limited to UI_CONFIRM_WINDOW_CHAR_WIDTH characters
ui_confirm_popup_show:
    .irp param,16,17,18,19,20,21
        push r\param
    .endr

    ldi r16, UI_CONFIRM_WINDOW_WIDTH * UI_CONFIRM_WINDOW_HEIGHT
    rcall mem_alloc
    mov r19, r16                                ; save memory pointer
    mov r20, r16                                ; save writing pointer for later

    ldi r21, UI_CONFIRM_WINDOW_HEIGHT           ; read UI_CONFIRM_WINDOW_HEIGHT rows worth of data

    ldi r16, UI_CONFIRM_START_PAGE
    ldi r17, UI_CONFIRM_START_COL

    rcall i2c_lock_acquire
_ui_confirm_read_next_row:
    push r16
    push r17
    rcall oled_set_relative_cursor              ; set cursor to start reading screen data to save in ram

    rcall oled_io_open_read_data
    ldi r18, UI_CONFIRM_WINDOW_WIDTH - 1        ; loop only n-1 times since last read needs to end with i2c_read_byte_nack
_ui_confirm_read_loop:
    rcall i2c_read_byte_ack                     ; read 1 byte
    mov r17, r16
    mov r16, r19
    rcall mem_store                             ; store the 1 byte (r17) in memory
    rcall mem_pointer_inc
    mov r19, r16
    dec r18
    brne _ui_confirm_read_loop
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
    brne _ui_confirm_read_next_row

    ; -----------------
    rcall _ui_confirm_util_display_popup
    ; -----------------

    rcall i2c_lock_release

    rcall nav_kbd_start                         ; start the navigation keyboard (blocking)

    mov r19, r20                                ; restore memory pointer
    ldi r21, UI_CONFIRM_WINDOW_HEIGHT           ; write UI_CONFIRM_WINDOW_HEIGHT rows worth of data

    ldi r16, UI_CONFIRM_START_PAGE
    ldi r17, UI_CONFIRM_START_COL

    rcall i2c_lock_acquire
_ui_confirm_write_next_row:
    push r16
    push r17
    rcall oled_set_relative_cursor              ; set cursor to start writing back data from ram to screen

    rcall oled_io_open_write_data
    ldi r18, UI_CONFIRM_WINDOW_WIDTH
_ui_confirm_write_loop:
    mov r16, r19
    rcall mem_load
    rcall mem_pointer_inc
    mov r19, r16
    mov r16, r17
    rcall i2c_send_byte
    dec r18
    brne _ui_confirm_write_loop
    rcall oled_io_close

    pop r17
    pop r16
    inc r16
    dec r21
    brne _ui_confirm_write_next_row

    rcall i2c_lock_release

    mov r16, r20                                ; restore memory pointer
    rcall mem_free

    rcall nav_kbd_start                         ; start the navigation keyboard

    .irp param,21,20,19,18,17,16
        pop r\param
    .endr
    ret
