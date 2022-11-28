
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
    rjmp _fm_print_file_icon
    ldi r16, ICON_IDX_FOLDER
    rcall oled_io_put_icon
    rjmp _fm_print_dir_entry_cb_print_start

_fm_print_file_icon:
    ldi r16, ICON_IDX_FILE
    rcall oled_io_put_icon

_fm_print_dir_entry_cb_print_start:
    ldi r16, ' '
    rcall oled_io_put_char
    rcall oled_io_close
_fm_print_dir_entry_cb_print:
    rcall fs_wrapper_read
    tst r16
    breq _fm_print_dir_entry_cb_print_end
    push r16
    rcall oled_io_open_write_data
    pop r16
    rcall oled_io_put_char
    rcall oled_io_close

    adiw r24, 1
    dec r18
    brne _fm_print_dir_entry_cb_print

_fm_print_dir_entry_cb_print_end:
    ; rcall oled_io_close

    pop r17
    pop r16
    inc r17
    rcall internal_fs_dir_item_idx_to_raw       ; this call puts the next item's signature in r16 to return (0 if last item is reached)
    rjmp _fm_print_dir_entry_done

_fm_print_dir_entry_cb_print_failed:
    pop r17
    pop r16

    clr r16

_fm_print_dir_entry_done:

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
    clr r24
    clr r25
_fm_app_show_menu:
    ldi r18, (1<<ENTER_BTN) | (1<<EXIT_BTN) | (1<<OPTIONS_BTN)         ; register all (ENTER_BTN, EXIT_BTN and OPTIONS_BTN) actions
    ldi r30, lo8(pm(fm_menu_print_dir_entry_cb))
    ldi r31, hi8(pm(fm_menu_print_dir_entry_cb))
    rcall ui_menu_show                         ; show dir listing

    ; sbrs r18, ENTER_BTN
    ; rjmp _fm_app_options

    ; rjmp _fm_app_show_menu

_fm_app_options:
    sbrs r18, OPTIONS_BTN
    rjmp _fm_app_exit

    rcall internal_fm_options_show
    rjmp _fm_app_show_menu

_fm_app_exit:
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






msg_fm_options:
    .asciz "New File"           ; index 0
    .asciz "New Folder"         ; index 1
    .asciz "Delete"             ; index 2
    .byte 0


msg_fm_enter_new_name:
    .asciz "name:"

.balign 2


; opens root directory as a menu
internal_fm_options_show:
    .irp param,16,17,18,24,25,30,31
        push r\param
    .endr

    push r16
    push r24
    push r25

    clr r16
    clr r17
    ldi r24, lo8(msg_fm_options)
    ldi r25, hi8(msg_fm_options)
_fm_options_show_menu:
    ldi r18, (1<<ENTER_BTN) | (1<<EXIT_BTN)    ; register ENTER_BTN and EXIT_BTN action
    ldi r30, lo8(pm(ui_menu_print_flash_item_cb))
    ldi r31, hi8(pm(ui_menu_print_flash_item_cb))
    rcall ui_menu_show                         ; show options menu

    sbrs r18, ENTER_BTN
    rjmp _fm_options_exit_btn                  ; if ENTER_BTN was not pressed, then EXIT_BTN was

    mov r18, r16
    pop r25
    pop r24
    pop r16

    cpi r18, 2
    brlo _fm_options_make_item

    ; delete current item (indexed by r16)
    ; r24 contains parent directory cluster index
    mov r17, r16
    mov r16, r24
    rcall fs_remove_item
    rjmp _fm_options_done

_fm_options_make_item:
    ldi r30, lo8(msg_fm_enter_new_name)
    ldi r31, hi8(msg_fm_enter_new_name)
    rcall ui_input_popup_show

    cpi r16, 0xff
    breq _fm_options_done

    mov r17, r16
    mov r16, r24                                ; r24 is what fm_app_open uses to track current directory cluster index

    tst r18                                     ; index 0 is new file
    brne _fm_options_make_dir

    rcall fs_file_make
    rjmp _fm_options_make_done

_fm_options_make_dir:
    rcall fs_dir_make

_fm_options_make_done:
    mov r16, r17
    rcall mem_free

    rjmp _fm_options_done

_fm_options_exit_btn:
    sbrs r18, EXIT_BTN
    rjmp _fm_options_show_menu
    pop r25
    pop r24
    pop r16

_fm_options_done:

    .irp param,31,30,25,24,18,17,16
        pop r\param
    .endr
    ret
