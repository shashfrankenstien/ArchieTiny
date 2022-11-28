; settings app
; - lists available settings using ui_menu_show
; - settings may use sliders (ui_slider_open) or menus (ui_menu_show)
; - on init, settings app checks eeprom and syncs all settings with corresponding registers
; - once any setting is edited, it will be written to eeprom


; describes settings list to display
; passed to ui_menu_show routine
settings_list_labels:
_settings_contrast_label:       .asciz "contrast"                          ; index 0
_settings_buzzer_volume_label:  .asciz "volume"                            ; index 1
_settings_buzzer_mute_label:    .asciz "toggle mute"                       ; index 2
    .byte 0                                    ; end of list

.balign 2


settings_app_open:
    .irp param,16,17,18,24,25,30,31
        push r\param
    .endr

    clr r16                                    ; first item in menu selected (0 indexed)
    clr r17                                    ; menu scroll position top
_settings_app_show_menu:
    rcall internal_settings_write_to_eeprom    ; make sure eeprom is updated

    ldi r18, (1<<ENTER_BTN) | (1<<EXIT_BTN)    ; register ENTER_BTN and EXIT_BTN action
    ldi r24, lo8(settings_list_labels)
    ldi r25, hi8(settings_list_labels)
    ldi r30, lo8(pm(ui_menu_print_flash_item_cb))
    ldi r31, hi8(pm(ui_menu_print_flash_item_cb))
    rcall ui_menu_show                         ; show settings menu
                                               ; let user select from settings_list_labels list. rcall appropriate routine using selected index

    sbrs r18, ENTER_BTN
    rjmp _settings_app_exit                    ; if ENTER_BTN was not pressed, then EXIT_BTN was

_settings_app_menu_0:
    cpi r16, 0
    brne _settings_app_menu_1
    push r16
    ldi r24, lo8(_settings_contrast_label)
    ldi r25, hi8(_settings_contrast_label)
    ldi r30, lo8(pm(oled_set_contrast))
    ldi r31, hi8(pm(oled_set_contrast))
    lds r16, SREG_OLED
    swap r16
    andi r16, 0b00001111                         ; keep only 4 low bits that contain contrast value
    rcall ui_slider_open
    pop r16

    rjmp _settings_app_show_menu                 ; show menu after running selected option

_settings_app_menu_1:
    cpi r16, 1
    brne _settings_app_menu_2
    push r16
    ldi r24, lo8(_settings_buzzer_volume_label)
    ldi r25, hi8(_settings_buzzer_volume_label)
    ldi r30, lo8(pm(buzzer_set_volume))
    ldi r31, hi8(pm(buzzer_set_volume))
    lds r16, BUZZER_VOLUME_REG
    andi r16, 0b00001111                         ; keep only 4 low bits that contain volume value
    rcall ui_slider_open
    pop r16

    rjmp _settings_app_show_menu                 ; show menu after running selected option

_settings_app_menu_2:
    cpi r16, 2
    brne _settings_app_menu_done
    rcall buzzer_toggle_mute
    ; TODO: write to eeprom here

_settings_app_menu_done:
    rjmp _settings_app_show_menu                 ; show menu after running selected option


_settings_app_exit:
    sbrs r18, EXIT_BTN
    rjmp _settings_app_show_menu

    push r16
    ldi r30, lo8(msg_ui_exit_confirm)
    ldi r31, hi8(msg_ui_exit_confirm)
    rcall ui_confirm_popup_show
    tst r16
    pop r16
    breq _settings_app_show_menu

    .irp param,31,30,25,24,18,17,16
        pop r\param
    .endr
    ret




internal_settings_write_to_eeprom:
    ; TODO: update all to eeprom here
    ret


internal_settings_read_from_eeprom:
    ret
