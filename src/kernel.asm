.include "config.inc"

; General registers / addresses

.equ    SPL,                0x3d
.equ    SPH,                0x3e
.equ    SREG,               0x3f


; repurpose r25 for gpio flags
; .req    r25,            r25


; MAIN PROGRAM

.org 0                              ; origin - address of next statement
; interrupt vector table
rjmp main                           ; address 0x0000 - RESET
reti                                ; address 0x0001 - INT0_ISR
rjmp gpio_btn_press_isr             ; address 0x0002 - PCINT0_ISR
reti                                ; address 0x0003 - TIM1_COMPA_ISR
reti                                ; address 0x0004 - TIM1_OVF_ISR
reti                                ; address 0x0005 - TIM0_OVF_ISR
reti                                ; address 0x0006 - EE_RDY_ISR
reti                                ; address 0x0007 - ANA_COMP_ISR
rjmp gpio_adc_conv_isr              ; address 0x0008 - ADC_ISR
reti                                ; address 0x0009 - TIM1_COMPB_ISR
rjmp timer_tick_isr                 ; address 0x000A - TIM0_COMPA_ISR
rjmp taskmanager_exec_next_isr      ; address 0x000B - TIM0_COMPB_ISR
reti                                ; address 0x000C - WDT_ISR
reti                                ; address 0x000D - USI_START_ISR
reti                                ; address 0x000E - USI_OVF_ISR




main:                               ; initialize
    cli
    ldi r16, lo8(RAMEND)            ; set stack pointer low bits to low(RAMEND)
    out SPL, r16
    ldi r16, hi8(RAMEND)            ; set stack pointer high bits to high(RAMEND)
    out SPH, r16

    ; clear gpio - set all to input
    clr r16
    out PORTB, r16
    out DDRB, r16

    rcall timer_init                ; set timer / counter options and intialize 24bit software counter
    rcall i2c_init                  ; initialize i2c bus
    rcall oled_init                 ; initialize i2c oled device (sh1107)
    rcall rtc_init                  ; initialize i2c RTC device (ds1307)
    rcall gpio_btn_init             ; intialize buttons as input pins and attach pc interrupts
    rcall gpio_adc_init             ; intialize ADC to read thumb wheel potentiometer
    rcall buzzer_init               ; intialize piezo buzzer for audio
    rcall mem_init                  ; initialize dynamic memory management (malloc)

    ; finally, intialize, setup and start taskmanager
    rcall taskmanager_init          ; initialize task manager table

    ; add shell ui task
    ldi r17, hi8(pm(shell_home_task))   ; add task to task manager table
    ldi r16, lo8(pm(shell_home_task))   ; pm() divides r17:r16 (task subroutine address) by 2
    rcall taskmanager_add

    ldi r17, hi8(pm(test3))             ; add task to task manager table
    ldi r16, lo8(pm(test3))
    rcall taskmanager_add

    cbi PORTB, BUZZER_PIN
    sei
pool:
    sleep                           ; wait for interrupts (required for simavr to perform correctly. good idea anyway)
    rjmp pool






test3:
    ldi r20, 250                                       ; set delay

test3_loop:
    rcall timer_delay_ms_short

    rcall i2c_rlock_acquire

    ldi r16, 6
    ldi r17, OLED_MAX_COL - (FONT_WIDTH * 2)            ; right position
    rcall oled_set_cursor                      ; set cursor to start writing data

    ldi r26, lo8(TASK_SP_VECTOR)                ; set XL to start of task stack pointers vector
    ldi r27, hi8(TASK_SP_VECTOR)                ; set XH to start of task stack pointers vector

    ld r16, X+
    subi r16, lo8(TASK_STACKS_TOP)
    rcall oled_print_hex_digits


    ; ldi r16, 6
    ; ldi r17, OLED_MAX_COL - (FONT_WIDTH * 8)            ; right position
    ; rcall oled_set_cursor                      ; set cursor to start writing data
    ; lds r16, SREG_ADC_VD_HLD
    ; rcall oled_print_binary_digits

    ; ldi r16, 7
    ; ldi r17, OLED_MAX_COL - (FONT_WIDTH * 8)            ; right position
    ; rcall oled_set_cursor                      ; set cursor to start writing data
    ; lds r16, SREG_ADC_VD_HLD
    ; rcall oled_print_binary_digits

    ldi r16, 7
    ldi r17, OLED_MAX_COL - (FONT_WIDTH * 2)            ; right position
    rcall oled_set_cursor                      ; set cursor to start writing data
    lds r16, ADC_CHAN_0_VAL
    rcall oled_print_hex_digits

    clr r17
    rcall i2c_rlock_acquire
    rcall rtc_io_open_reader
    rcall i2c_read_byte_nack
    mov r18, r16
    rcall rtc_io_close
    rcall i2c_rlock_release

    ldi r16, 5
    ldi r17, OLED_MAX_COL - (FONT_WIDTH * 2)            ; right position
    rcall oled_set_cursor                      ; set cursor to start writing data

    mov r16, r18
    rcall oled_print_hex_digits

;     ldi r16, 1
;     ldi r17, OLED_MAX_COL - (FONT_WIDTH * 8)            ; right top position
;     rcall oled_set_cursor                      ; set cursor to start writing data

;     rcall oled_io_open_read_data

;     ldi r18, 9
; test3_read_loop:
;     rcall i2c_read_byte_ack
;     push r16
;     dec r18
;     brne test3_read_loop
;     rcall i2c_read_byte_nack
;     push r16
;     rcall oled_io_close

;     ldi r16, 7
;     ldi r17, 0
;     rcall oled_set_cursor                      ; set cursor to start writing data

;     ldi r18, 10
; test3_write_loop:
;     pop r16                               ; load back the fill byte that was originally saved away
;     rcall oled_print_hex_digits
;     dec r18
;     brne test3_write_loop

    rcall i2c_rlock_release
    rjmp test3_loop



; test_display:
;     push r16
;     push r17
;     push r18
;     push r22

;     mov r22, r16

;     rcall i2c_rlock_acquire
;     ldi r16, 7
;     ldi r17, 0            ; right top position
;     rcall oled_set_cursor                      ; set cursor to start writing data
;     mov r16, r22
;     rcall oled_print_hex_digits
;     rcall i2c_rlock_release
;     pop r22
;     pop r18
;     pop r17
;     pop r16
;     ret


; test_display2:
;     push r16
;     push r17
;     push r18
;     push r22
;     mov r22, r16

;     rcall i2c_rlock_acquire
;     ldi r16, 6
;     ldi r17, 0            ; right top position
;     rcall oled_set_cursor                      ; set cursor to start writing data
;     mov r16, r22
;     rcall oled_print_hex_digits
;     rcall i2c_rlock_release
;     pop r22
;     pop r18
;     pop r17
;     pop r16
;     ret
