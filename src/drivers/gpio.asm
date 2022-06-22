.include "config.inc"                       ; BUZZER_PIN, GPIO_BTN_0, ADC_CHAN_0, SREG_GPIO_PC, ...

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
.equ    ADC_CTRL_A,         0b00001111      ; Bit 3 – ADIE: ADC Interrupt Enable
                                            ; Bits 2:0 – ADPS[2:0]: ADC Prescaler Select Bits (111 divides sys clock by 128)
; control bits
.equ    ADEN,               7               ; ADCSRA Bit 7 – ADEN: ADC Enable (use this to turn on and off ADC - turn off before sleep to save power)
.equ    ADSC,               6               ; ADCSRA Bit 6 - ADC Start Conversion bit
; .equ    ADIF,               4               ; ADCSRA Bit 4 – ADIF: ADC Interrupt Flag


.equ    ADCSRB,             0x03            ; ADCSRB – ADC Control and Status Register B
.equ    ADC_CTRL_B,         0b00000000      ; Bits 2:0 – ADTS[2:0]: ADC Auto Trigger Source (000 default. we will manually trigger using ADSC)


.equ    ADCH,               0x05            ; ADCH – The ADC Data Register high byte (read only this when ADLAR is set)
.equ    ADCL,               0x04            ; ADCL – The ADC Data Register low byte



; SREG_GPIO_PC - gpio status register (pin change interrupts)
;   - register holds 8 gpio status flags
;      -----------------------------------------------------------------------------------
;      |  N/A  |  N/A  |  N/A  | GPIO_BTN_0_HLD |  N/A  |  N/A  |  N/A  | GPIO_BTN_0_PRS |
;      -----------------------------------------------------------------------------------
;
; GPIO_BTN_x_PRS - where x is 0, 1 or 2
;   - flag is set when a falling edge is detected on button x
;   - this flag should be cleared after action is taken about the press
; GPIO_BTN_x_HLD - where x is 0, 1 or 2
;   - flag is set when a falling edge is detected and cleared when rising edge is detected on button x
;
; *I only GPIO_BTN_0 used for now

.equ    GPIO_BTN_0_PRS,     0
.equ    GPIO_BTN_0_HLD,     GPIO_BTN_0_PRS + 4

; --------------------------------------------------------------------------------

; SREG_ADC_VD_HLD - button status register (voltage divided ADC)
; - register is dynamically updated from 'gpio_adc_vd_btn_read' and also returned in r16
;   - SREG_ADC_VD_HLD holds upto 8 flags indicating a button hold
;   - only 5 assigned for now
;      --------------------------------------------------------------------------------------------------------------------------------------------------------------
;      |  ADC_VD_CH1_BTN_2  |  ADC_VD_CH1_BTN_1  |  ADC_VD_CH1_BTN_0  | ADC_VD_CH0_BTN_4 | ADC_VD_CH0_BTN_3 | ADC_VD_CH0_BTN_2 | ADC_VD_CH0_BTN_1 | ADC_VD_CH0_BTN_0 |
;      ---------------------------------------------------------------------------------------------------------------------------------------------------------------


; --------------------------------------------------------------------------------


; intialize PC interrupt
; - inputs are set to active low by enabling pull-up registers
gpio_btn_init:
    push r16
    ldi r16, (1<<PC_INT_ENABLE)
    out GIMSK, r16

    sbi PORTB, GPIO_BTN_0                      ; pull high (active low)
    cbi DDRB, GPIO_BTN_0

    ldi r16, (1<<GPIO_BTN_0)
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

    ldi r20, PC_BTN_WAIT_INTERVAL
    rcall timer_delay_clock_cycles              ; wait a bit to allow pin to stabilize

    lds r17, SREG_GPIO_PC

    in r16, PINB
    sbrs r16, GPIO_BTN_0                        ; active low. act only if cleared
    ori r17, (1<<GPIO_BTN_0_PRS) | (1<<GPIO_BTN_0_HLD)
    sbrc r16, GPIO_BTN_0                        ; if button is set, clear HLD flag
    cbr r17, (1<<GPIO_BTN_0_HLD)

    sts SREG_GPIO_PC, r17

    pop r20
    pop r17
    pop r16
    reti


; --------------------------------------------------------------------------------
; ADC routines

; intializes ADC (ADC_CHAN_0)
gpio_adc_init:
    sbi PORTB, ADC_CHAN_0_PIN                 ; enable pullup resistor
    sbi PORTB, ADC_CHAN_1_PIN                 ; enable pullup resistor

    ldi r16, ADC_MUX_SETTINGS | ADC_CHAN_0    ; select ADC channel
    out ADMUX, r16

    ldi r16, ADC_CTRL_A                       ; set clock prescaler
    out ADCSRA, r16

    ldi r16, ADC_CTRL_B                       ; default byte 0 (all low)
    out ADCSRB, r16

    cbi ADCSRA, ADEN                          ; keep ADC off

    clr r16
    sts SREG_ADC_VD_HLD, r16                  ; clear ADC button status register
    ret


; handle ADC conversion complete interrupt
; - ADC can be stabilized with a small-ish capacitor
; - [TODO]
; - this ISR will read, use and increment ADMUX MUX[3:0]
;       - this will enable it to read the next configured ADC during the following ADC interrupt
;       - also, by reading ADMUX MUX[3:0], it can store the conversion in the correct ADC_CHAN_x_VAL register
; - a new conversion is triggered before reti
gpio_adc_conv_isr:
    push r16
    push r17
    in r17, SREG

    in r16, ADMUX
    andi r16, 0x0f                            ; check MUX[3:0]
    cpi r16, ADC_CHAN_0
    brne gpio_adc_conv_isr_chan1

    in r16, ADCH                              ; read ADC converted data (high byte resolution only)
    sts ADC_CHAN_0_VAL, r16
    ldi r16, ADC_MUX_SETTINGS | ADC_CHAN_1    ; select next ADC channel
    out ADMUX, r16
    rjmp gpio_adc_conv_isr_done

gpio_adc_conv_isr_chan1:
    cpi r16, ADC_CHAN_1
    brne gpio_adc_conv_isr_done

    in r16, ADCH                              ; read ADC converted data (high byte resolution only)
    sts ADC_CHAN_1_VAL, r16
    ldi r16, ADC_MUX_SETTINGS | ADC_CHAN_0    ; select next ADC channel
    out ADMUX, r16

gpio_adc_conv_isr_done:
    out SREG, r17
    pop r17
    pop r16
    sbi ADCSRA, ADSC                          ; start next ADC conversion
    reti



; [TODO] add comments
; voltage levels are checked to be below each threshold
; lowest voltage thresholds are checked first to avoid false positives
; checks are repeated ADC_BTN_NUM_RE_READS number of times with ADC_BTN_RE_READ_INTERVAL delay between each reading
; if all ADC_BTN_NUM_RE_READS readings are the same, button press is reported
gpio_adc_vd_btn_read:
    .irp param,17,18,19,20
        push r\param
    .endr

    sbi ADCSRA, ADEN                        ; turn on ADC
    sbi ADCSRA, ADSC                        ; start ADC conversions

    clr r16                                 ; clear r16 to hold output
    ldi r17, 0xff                           ; r17 will hold previous iteration r16 state. first iteration is indicated by 0xff

    ldi r19, ADC_BTN_NUM_RE_READS           ; total number of consecutinve readings required
    ldi r20, ADC_BTN_RE_READ_INTERVAL       ; set sleep time
    ; rjmp _adc_vd_handle_c0b0

_adc_vd_handle_sleep_restart:
    rcall timer_delay_ms_short

_adc_vd_handle_c0b0:
    lds r18, ADC_CHAN_0_VAL                 ; read ADC byte into r18 (ADLAR = 1; 8 bit precision)

    cpi r18, ADC_VD_CH0_BTN_0_TRESH
    brsh _adc_vd_handle_c0b1
    sbr r16, (1<<ADC_VD_CH0_BTN_0)
    rjmp _adc_vd_handle_c1b0

_adc_vd_handle_c0b1:
    cpi r18, ADC_VD_CH0_BTN_1_TRESH
    brsh _adc_vd_handle_c0b2
    sbr r16, (1<<ADC_VD_CH0_BTN_1)
    rjmp _adc_vd_handle_c1b0

_adc_vd_handle_c0b2:
    cpi r18, ADC_VD_CH0_BTN_2_TRESH
    brsh _adc_vd_handle_c0b3
    sbr r16, (1<<ADC_VD_CH0_BTN_2)
    rjmp _adc_vd_handle_c1b0

_adc_vd_handle_c0b3:
    cpi r18, ADC_VD_CH0_BTN_3_TRESH
    brsh _adc_vd_handle_c0b4
    sbr r16, (1<<ADC_VD_CH0_BTN_3)
    rjmp _adc_vd_handle_c1b0

_adc_vd_handle_c0b4:
    cpi r18, ADC_VD_CH0_BTN_4_TRESH
    brsh _adc_vd_handle_c1b0
    sbr r16, (1<<ADC_VD_CH0_BTN_4)
    ; rjmp _adc_vd_handle_c1b0

_adc_vd_handle_c1b0:
    lds r18, ADC_CHAN_1_VAL                 ; read ADC byte into r18 (ADLAR = 1; 8 bit precision)

    cpi r18, ADC_VD_CH1_BTN_0_TRESH
    brsh _adc_vd_handle_c1b1
    sbr r16, (1<<ADC_VD_CH1_BTN_0)
    rjmp _adc_vd_handle_btn_done

_adc_vd_handle_c1b1:
    cpi r18, ADC_VD_CH1_BTN_1_TRESH
    brsh _adc_vd_handle_c1b2
    sbr r16, (1<<ADC_VD_CH1_BTN_1)
    rjmp _adc_vd_handle_btn_done

_adc_vd_handle_c1b2:
    cpi r18, ADC_VD_CH1_BTN_2_TRESH
    brsh _adc_vd_handle_btn_done
    sbr r16, (1<<ADC_VD_CH1_BTN_2)
    ; rjmp _adc_vd_handle_btn_done

_adc_vd_handle_btn_done:
    cpi r17, 0xff                           ; check if in first iteration
    brne _adc_vd_handle_iter_compare
    mov r17, r16                            ; mov r16 to r17 in the first iteration
_adc_vd_handle_iter_compare:
    cpse r16, r17
    rjmp _adc_vd_all_error                  ; if previous and current state is not same, fail with error
    mov r17, r16                            ; save current state r16 to prev state r17
    dec r19
    brne _adc_vd_handle_sleep_restart

    lds r18, SREG_ADC_VD_HLD                ; finished without error. update SREG_ADC_VD_HLD
    sts SREG_ADC_VD_HLD, r16
    cpse r16, r18                           ; compare previous and current reading. if equal, determine that the button is still pressed
    rjmp _adc_vd_all_done

_adc_vd_all_error:
    clr r16                                 ; if any iteration compare failed, or if button is still pressed, return 0 (nothing)

_adc_vd_all_done:
    cbi ADCSRA, ADEN                        ; turn off ADC

    .irp param,20,19,18,17
        pop r\param
    .endr
    ret
