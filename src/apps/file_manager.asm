
; file manager
; - uses ui_menu_show to list directories
; - implements
;       - create new file / directory
;       - delete file / directory
;       - rename file / directory


; conforms to ui menu requirements
;   - takes directory cluster index in r25:r24 (we'll just use the LSB in r24 as directory cluster index)
;   - take index of directory entry to print in r16 and print 1 item at current cursor
;   - return 0 in r16 if index is out of menu bounds
;   - return 0 in r16 if the last item was reached and printed. else return whatever
fm_menu_print_dir_entry_cb:
    .irp param,17,18,24,25
        push r\param
    .endr

    mov r17, r16
    mov r16, r24
    push r16
    push r17                                    ; saving for later
    rcall internal_fs_dir_item_idx_to_raw
    tst r16                                     ; signature is in r16
    breq _fm_print_dir_entry_cb_print_failed
    mov r17, r16                                ; save signature for later

    adiw r24, 1
    ldi r18, FS_DIR_ENTRY_NAME_MAX_LEN
    rcall oled_io_open_write_data

    ldi r16, ICON_IDX_TREE
    rcall oled_io_put_icon

    sbrs r17, FS_IS_DIR
    rjmp _fm_print_dir_entry_cb_print_start
    ldi r16, ICON_IDX_FOLDER
    rcall oled_io_put_icon

_fm_print_dir_entry_cb_print_start:
    ldi r16, ' '
    rcall oled_io_put_char
_fm_print_dir_entry_cb_print:
    rcall eeprom_read
    tst r16
    breq _fm_print_dir_entry_cb_print_done
    rcall oled_io_put_char

    adiw r24, 1
    dec r18
    brne _fm_print_dir_entry_cb_print

_fm_print_dir_entry_cb_print_done:
    rcall oled_io_close

    pop r17
    pop r16
    inc r17
    rcall internal_fs_dir_item_idx_to_raw       ; this call puts the next item's signature in r16 to return (0 if last item is reached)

_fm_print_dir_entry_cb_print_failed:

    .irp param,25,24,18,17
        pop r\param
    .endr
    ret




; opens root directory as a menu
fm_app_open:
    .irp param,16,17,18,24,25,30,31
        push r\param
    .endr

    clr r16
    clr r17
_fm_app_show_menu:
    clr r24
    clr r25
    ldi r30, lo8(pm(fm_menu_print_dir_entry_cb))
    ldi r31, hi8(pm(fm_menu_print_dir_entry_cb))
    rcall ui_menu_show                         ; show apps menu

    sbrs r18, EXIT_BTN
    rjmp _fm_app_show_menu

    push r16
    ldi r30, lo8(msg_ui_exit_confirm)
    ldi r31, hi8(msg_ui_exit_confirm)
    rcall ui_confirm_popup_show
    tst r16
    pop r16
    breq _fm_app_show_menu

    .irp param,31,30,25,24,18,17,16
        pop r\param
    .endr
    ret
