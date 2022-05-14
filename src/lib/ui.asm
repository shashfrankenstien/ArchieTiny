; this file implements a bunch of ui components
;   - menu
;   - confirm window


; reusable scrollable menu component
; takes address to the menu item names list in Z pointer
; returns the selected index out of the menu items in r16
ui_menu_show:
    .irp param,17,18,19,20,21,22,23,24,25,26
        push r\param
    .endr

    mov r25, r30                                ; save input Z pointer value in r26:r25 (first menu item)
    mov r26, r31

    clr r20                                     ; r20 keeps count of total number of items in the menu
    clr r17                                     ; r17 is the start column address. this can be offset?
    ldi r18, OLED_MAX_COL                       ; r18 is the end column address for highlighting. this can be offset too!
    clr r19                                     ; r19 indicates the page (row) number the nav cursor is on (first item by default)
    clr r21                                     ; r21 contains the current item number that the nav cursor is on
    clr r22                                     ; r22 contains previous nav cursor item number.
                                                ;       if this is different from r21, highlight operation is performed
    clr r23                                     ; scroll position tracker
    clr r24                                     ; flags register - end of menu reached flag, row highlighted flag

    rcall i2c_lock_acquire
    rcall oled_clr_screen
    rcall i2c_lock_release

_ui_menu_next:
    mov r16, r19                                ; move page (row) address from r19 into t16. r17 already points to start column
    rcall i2c_lock_acquire
    rcall oled_set_relative_cursor              ; set cursor to start writing data

    rcall oled_print_flash                      ; print one entry from the list pointed by Z pointer (until \0 is encountered)
    rcall i2c_lock_release
    inc r20

    lpm r16, Z                                  ; peek next byte to check if we reached the end of list
    tst r16
    breq _ui_menu_last_item_shown

    cpi r19, OLED_MAX_PAGE
    breq _ui_menu_navigate

    inc r19
    rjmp _ui_menu_next

; ------
_ui_menu_scroll_prev:
    dec r20
    cbr r24, (1<<0)                             ; remove end of menu flag since while scrolling up, we're most likely not showing end of menu anymore
    rcall _ui_menu_util_Z_previous_item         ; move current Z pointer back to previous item (this is the bottom of the display)

    ; start at the beginning of the menu and print r21 indexed item on the top row
    push r30
    push r31

    mov r30, r25                                ; reload original Z pointer (first menu item)
    mov r31, r26

    mov r16, r21
    rcall _ui_menu_util_Z_next_nth_item

    mov r16, r21
    sub r16, r23
    rcall i2c_lock_acquire
    rcall oled_set_relative_cursor              ; set cursor to start writing data
    rcall oled_print_flash                      ; print one entry from the list pointed by Z pointer (until \0 is encountered)
    rcall i2c_lock_release

    pop r31
    pop r30
    rjmp _ui_menu_navigate
; ------

_ui_menu_last_item_shown:
    sbr r24, (1<<0)                             ; flag that end of menu reached

_ui_menu_navigate:
    sbrs r24, 1                                 ; check if any row is highlighted
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
    sbr r24, (1<<1)                             ; flag that a row is currently highlighted

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
    dec r21
    dec r23
    rcall i2c_lock_acquire
    rcall oled_scroll_page_up
    rcall i2c_lock_release
    rjmp _ui_menu_scroll_prev

_ui_menu_nav_move_up:
    dec r21                                     ; move selection up
    rjmp _ui_menu_navigate


_ui_menu_nav_check_down:
    cpi r16, NAV_DOWN
    brne _ui_menu_nav_check_ok                  ; if nav is not DOWN, continue to check OK

    inc r21                                     ; move selection down
    cpse r21, r20
    rjmp _ui_menu_navigate

    sbrc r24, 0                                 ; if bottom is reached, set selection back (essentially do nothing)
    dec r21
    sbrc r24, 0
    rjmp _ui_menu_navigate

    ; scroll
    inc r23
    rcall i2c_lock_acquire
    rcall oled_scroll_page_down
    rcall i2c_lock_release
    rjmp _ui_menu_next


_ui_menu_nav_check_ok:
    cpi r16, NAV_OK
    brne _ui_menu_navigate                      ; if nav is not OK, go back and start over

    mov r16, r21                                ; if OK is pressed, return current selected item index to calling routine

    .irp param,26,25,24,23,22,21,20,19,18,17
        pop r\param
    .endr
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









; reusable confirm y/n popup component
; takes address to the confirm message in Z pointer
ui_confirm_window:
    .irp param,16,17,18,19,20,21
        push r\param
    .endr

    ldi r21, MALLOC_MAX_BLOCKS
    ldi r21, 2

    rcall i2c_lock_acquire

    mov r16, r21
    ldi r17, 10
    rcall oled_set_cursor                      ; set cursor to start writing data

    rcall oled_io_open_read_data

    ldi r18, (FONT_WIDTH * 8) - 1
    mov r16, r18
    rcall mem_alloc
    mov r19, r16
    mov r20, r16

_ui_confirm_read_loop:
    rcall i2c_read_byte_ack
    mov r17, r16
    mov r16, r19
    rcall mem_store
    rcall mem_pointer_inc
    mov r19, r16
    dec r18
    brne _ui_confirm_read_loop
    rcall i2c_read_byte_nack
    mov r17, r16
    mov r16, r19
    rcall mem_store
    rcall oled_io_close
    ; rcall i2c_lock_release

    mov r16, r21
    ldi r17, 10
    rcall oled_set_cursor                      ; set cursor to start writing data

    lds r16, SREG_GPIO_PC
    rcall oled_print_binary_digits
    rcall i2c_lock_release

    rcall nav_kbd_start                        ; start the navigation keyboard


    rcall i2c_lock_acquire

    mov r16, r21
    ldi r17, 10
    rcall oled_set_cursor                      ; set cursor to start writing data

    rcall oled_io_open_write_data

    ldi r18, (FONT_WIDTH * 8)
    mov r19, r20

_ui_confirm_write_loop:
    mov r16, r19
    rcall mem_load
    rcall mem_pointer_inc
    mov r19, r16
    mov r16, r17
    rcall i2c_send_byte                        ; i2c_send_byte modifies r16, so we need to reload r16 at every iteration
    dec r18
    brne _ui_confirm_write_loop

    rcall oled_io_close
    rcall i2c_lock_release

    mov r16, r20
    rcall mem_free

    rcall nav_kbd_start                         ; start the navigation keyboard

    .irp param,21,20,19,18,17,16
        pop r\param
    .endr
    ret
