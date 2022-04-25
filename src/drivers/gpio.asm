.include "config.inc"                       ; LED_PIN, GPIO_BTN_0, ADC_CHAN_0, SREG_GPIO_PC

; gpio mode, write and read registers
.equ    DDRB,               0x17
.equ    PORTB,              0x18
.equ	PINB,               0x16


; pin change interrupt control
.equ    GIMSK,              0x3b            ; GIMSK – General Interrupt Mask Register
.equ    PC_INT_ENABLE,      5               ; bit 5 is PCIE (bit 6 is INT0 enable)

.equ    PCMSK,              0x15            ; PCMSK – Pin Change Mask Register - bits 0 through 5 enable PCINT 0 through 5

; --------------------------------------------------------------------------------
; ADC settings
.equ    ADMUX,              0x07            ; ADMUX - ADC Multiplexer Selection Register
.equ    ADC_MUX_SETTINGS,   0b00100000      ; Bits 4,7:6 – REFS[2:0]: Voltage Reference Selection Bits (000 selects Vcc as reference)
                                            ; ADLAR: ADC left adjust result (bit 5) is set
                                            ;   this means 8 significant bits can be read from ADCH byte (reduces accuracy by 2 LSB)
                                            ; Bits 3:0 – MUX[3:0]: Analog Channel and Gain Selection Bits (0000 selects ADC0 channel)

.equ    ADCSRA,             0x06            ; ADCSRA – ADC Control and Status Register A
.equ    ADC_CTRL_A,         0b00101111      ; Bit 5 – ADATE: ADC Auto Trigger Enable
                                            ; Bit 3 – ADIE: ADC Interrupt Enable
                                            ; Bits 2:0 – ADPS[2:0]: ADC Prescaler Select Bits (111 divides sys clock by 128)
; control bits
.equ    ADEN,               7               ; ADCSRA Bit 7 – ADEN: ADC Enable (use this to turn on and off ADC - turn off before sleep to save power)
.equ    ADSC,               6               ; ADCSRA Bit 6 - ADC Start Conversion bit
; .equ    ADIF,               4               ; ADCSRA Bit 4 – ADIF: ADC Interrupt Flag


.equ    ADCSRB,             0x03            ; ADCSRB – ADC Control and Status Register B
.equ    ADC_CTRL_B,         0b00000000      ; Bits 2:0 – ADTS[2:0]: ADC Auto Trigger Source (000 enable free-running mode if ADATE and ADIE are set)


.equ    ADCH,               0x05            ; ADCH – The ADC Data Register high byte (read only this when ADLAR is set)
.equ    ADCL,               0x04            ; ADCL – The ADC Data Register low byte



; SREG_GPIO_PC - gpio status register (pin change interrupts)
;   - register holds 8 gpio status flags
;      -----------------------------------------------------------------------------------------------------------------------
;      |  N/A  |  N/A  | GPIO_BTN_2_HLD | GPIO_BTN_1_HLD | GPIO_BTN_0_HLD | GPIO_BTN_2_PRS | GPIO_BTN_1_PRS | GPIO_BTN_0_PRS |
;      -----------------------------------------------------------------------------------------------------------------------
;
; GPIO_BTN_x_PRS - where x is 0, 1 or 2
;   - flag is set when a falling edge is detected on button x
;   - this flag should be cleared after action is taken about the press
; GPIO_BTN_x_HLD - where x is 0, 1 or 2
;   - flag is set when a falling edge is detected and cleared when rising edge is detected on button x

.equ    GPIO_BTN_0_PRS,     0
.equ    GPIO_BTN_1_PRS,     1
.equ    GPIO_BTN_2_PRS,     2

.equ    GPIO_BTN_0_HLD,     GPIO_BTN_0_PRS + 3
.equ    GPIO_BTN_1_HLD,     GPIO_BTN_1_PRS + 3
.equ    GPIO_BTN_2_HLD,     GPIO_BTN_2_PRS + 3

; --------------------------------------------------------------------------------

; SREG_ADC_VD_HLD - button status register (voltage divided ADC)
; - register is dynamically updated from 'gpio_adc_vd_btn_read' and also returned in r16
;   - SREG_ADC_VD_HLD holds upto 8 flags indicating a button hold
;   - only 5 assigned for now
;      ----------------------------------------------------------------------------------------------------
;      |  N/A  |  N/A  |  N/A  | ADC_VD_BTN_4 | ADC_VD_BTN_3 | ADC_VD_BTN_2 | ADC_VD_BTN_1 | ADC_VD_BTN_0 |
;      ----------------------------------------------------------------------------------------------------


; --------------------------------------------------------------------------------

; digital IO routines
init_onboard_led:
    clr r16
    out PORTB, r16
    out DDRB, r16
    sbi DDRB, LED_PIN                          ; setup output pin 1 (P1)
    ret


; intialize PC interrupt
; - inputs are set to active low by enabling pull-up registers
gpio_btn_init:
    push r16
    ldi r16, (1<<PC_INT_ENABLE)
    out GIMSK, r16

    sbi PORTB, GPIO_BTN_0                      ; pull high (active low)
    sbi PORTB, GPIO_BTN_1                      ; pull high (active low)
    cbi DDRB, GPIO_BTN_0
    cbi DDRB, GPIO_BTN_1

    ldi r16, (1<<GPIO_BTN_0) | (1<<GPIO_BTN_1)
    out PCMSK, r16                             ; enable button 1 pin change interrupt

    clr r16
    sts SREG_GPIO_PC, r16                      ; clear gpio button status register

    pop r16
    ret


; handle PC interrupt
; - assumes that debouncing is handled by hardware (simple RC circuit. schmitt trigger may be overkill)
; - additionally, waits around 30 us for pin to stabilize
gpio_btn_press_isr:
    push r16
    push r17
    push r20

    ldi r20, 100
    rcall timer_delay_clock_cycles              ; wait a bit to allow pin to stabilize

    lds r17, SREG_GPIO_PC

    in r16, PINB
    sbrs r16, GPIO_BTN_0                        ; active low. act only if cleared
    ori r17, (1<<GPIO_BTN_0_PRS) | (1<<GPIO_BTN_0_HLD)
    sbrc r16, GPIO_BTN_0                        ; if button is set, clear HLD flag
    cbr r17, (1<<GPIO_BTN_0_HLD)

    sbrs r16, GPIO_BTN_1                        ; active low. act only if cleared
    ori r17, (1<<GPIO_BTN_1_PRS) | (1<<GPIO_BTN_1_HLD)
    sbrc r16, GPIO_BTN_1                        ; if button is set, clear HLD flag
    cbr r17, (1<<GPIO_BTN_1_HLD)

    sts SREG_GPIO_PC, r17

    pop r20
    pop r17
    pop r16
    reti


; --------------------------------------------------------------------------------
; ADC routines

; intializes ADC (ADC_CHAN_0)
gpio_adc_init:
    ldi r16, ADC_MUX_SETTINGS | ADC_CHAN_0    ; select ADC channel
    out ADMUX, r16

    ldi r16, ADC_CTRL_A                       ; set clock prescaler
    out ADCSRA, r16

    ldi r16, ADC_CTRL_B                       ; set free-running mode
    out ADCSRB, r16

    sbi ADCSRA, ADEN                          ; turn on ADC
    sbi ADCSRA, ADSC                          ; start free running ADC conversion

    clr r16
    sts SREG_ADC_VD_HLD, r16                  ; clear ADC button status register
    ret


; handle ADC conversion complete interrupt
; - ADC can be stabilized with a small-ish capacitor
; - [TODO]
; - this ISR will read, use and increment ADMUX MUX[3:0]
;       - this will enable it to read the next configured ADC during the following ADC interrupt
;       - also, by reading ADMUX MUX[3:0], it can store the conversion in the correct ADC_CHAN_x_VAL register
gpio_adc_conv_isr:
    push r16
    in r16, ADCH
    sts ADC_CHAN_0_VAL, r16
    pop r16
    reti



; [TODO] add comments
gpio_adc_vd_btn_read:
    .irp param,17,18,20
        push r\param
    .endr
    clr r16
    ldi r18, ADC_BTN_NUM_RE_READS           ; total number of consecutinve readings required
    ldi r20, ADC_BTN_RE_READ_INTERVAL       ; set sleep time
    rjmp _adc_vd_handle_btn0

_adc_vd_handle_sleep_restart:
    rcall timer_delay_ms_short

_adc_vd_handle_btn0:
    lds r17, ADC_VD_BTNS_VAL                 ; read ADC high byte into r17 (ADLAR = 1; 8 bit precision)

    cpi r17, ADC_VD_BTN_0_TRESH
    brsh _adc_vd_handle_btn1
    ldi r16, (1<<ADC_VD_BTN_0)
    rjmp _adc_vd_handle_btn_done

_adc_vd_handle_btn1:
    cpi r17, ADC_VD_BTN_1_TRESH
    brsh _adc_vd_handle_btn2
    ldi r16, (1<<ADC_VD_BTN_1)
    rjmp _adc_vd_handle_btn_done

_adc_vd_handle_btn2:
    cpi r17, ADC_VD_BTN_2_TRESH
    brsh _adc_vd_handle_btn3
    ldi r16, (1<<ADC_VD_BTN_2)
    rjmp _adc_vd_handle_btn_done

_adc_vd_handle_btn3:
    cpi r17, ADC_VD_BTN_3_TRESH
    brsh _adc_vd_handle_btn4
    ldi r16, (1<<ADC_VD_BTN_3)
    rjmp _adc_vd_handle_btn_done

_adc_vd_handle_btn4:
    cpi r17, ADC_VD_BTN_4_TRESH
    brsh _adc_vd_handle_btn_done
    ldi r16, (1<<ADC_VD_BTN_4)
    rjmp _adc_vd_handle_btn_done

_adc_vd_handle_btn_done:
    push r16
    dec r18
    brne _adc_vd_handle_sleep_restart

    pop r16
    ldi r18, ADC_BTN_NUM_RE_READS - 1
_adc_vd_handle_iter_compare:
    pop r17
    cpse r16, r17
    clr r16
    dec r18
    brne _adc_vd_handle_iter_compare

    lds r17, SREG_ADC_VD_HLD
    sts SREG_ADC_VD_HLD, r16
    cpse r16, r17                           ; compare previous and current reading. if equal, determine that the button is still pressed
    rjmp _adc_vd_all_done
    clr r16                                 ; if button is still pressed, return nothing

_adc_vd_all_done:
    .irp param,20,18,17
        pop r\param
    .endr
    ret