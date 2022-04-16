.include "config.inc"                       ; LED_PIN, GPIO_BTN_0, THUMB_WHEEL_CHANNEL, SREG_GPIO

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
.equ    ADC_MUX_SETTINGS,   0b00100000      ; Bits 7:6, 4 – REFS[2:0]: Voltage Reference Selection Bits (000 selects Vcc as reference)
                                            ; ADLAR: ADC left adjust result (bit 5) is set
                                            ;   this means 8 significant bits can be read from ADCH byte (reduces accuracy by 2 LSB)
                                            ; Bits 3:0 – MUX[3:0]: Analog Channel and Gain Selection Bits (0000 selects ADC0 channel)

.equ    ADCSRA,             0x06            ; ADCSRA – ADC Control and Status Register A
.equ    ADC_CTRL_A,         0b00100111      ; Bit 5 – ADATE: ADC Auto Trigger Enable
                                            ; Bits 2:0 – ADPS[2:0]: ADC Prescaler Select Bits (111 divides sys clock by 128)
; control bits
.equ    ADEN,               7               ; ADCSRA Bit 7 – ADEN: ADC Enable (use this to turn on and off ADC - turn off before sleep to save power)
.equ    ADSC,               6               ; ADCSRA Bit 6 - ADC Start Conversion bit


.equ    ADCSRB,             0x03            ; ADCSRB – ADC Control and Status Register B
.equ    ADC_CTRL_B,         0b00000000      ; Bits 2:0 – ADTS[2:0]: ADC Auto Trigger Source (000 enable free-running mode)


.equ    ADCH,               0x05            ; ADCH – The ADC Data Register high byte (read only this when ADLAR is set)
.equ    ADCL,               0x04            ; ADCL – The ADC Data Register low byte



; SREG_GPIO - gpio status register
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


; digital IO routines
init_onboard_led:
    clr r16
    out PORTB, r16
    out DDRB, r16
    sbi DDRB, LED_PIN                ; setup output pin 1 (P1)
    ret


; intialize PC interrupt
; - inputs are set to active low by enabling pull-up registers
gpio_btn_init:
    push r16
    ldi r16, (1<<PC_INT_ENABLE)
    out GIMSK, r16

    sbi PORTB, GPIO_BTN_0                      ; pull high (active low)
    cbi DDRB, GPIO_BTN_0

    sbi PORTB, GPIO_BTN_1                      ; pull high (active low)
    cbi DDRB, GPIO_BTN_1

    ldi r16, (1<<GPIO_BTN_0) | (1<<GPIO_BTN_1)
    out PCMSK, r16                             ; enable button 1 pin change interrupt

    clr r16
    sts SREG_GPIO, r16                          ; clear gpio status register

    pop r16
    ret


; handle PC interrupt
; - this isr has software check to only trigger on falling edge??
; - assumes that debouncing is handled by hardware (simple RC circuit. schmitt trigger may be overkill)
gpio_btn_press_isr:
    push r16
    push r17

    lds r17, SREG_GPIO

    in r16, PINB
    sbrs r16, GPIO_BTN_0                        ; active low. act only if cleared
    ori r17, (1<<GPIO_BTN_0_PRS) | (1<<GPIO_BTN_0_HLD)
    sbrc r16, GPIO_BTN_0                        ; if button is set, clear HLD flag
    cbr r17, (1<<GPIO_BTN_0_HLD)

    sbrs r16, GPIO_BTN_1                        ; active low. act only if cleared
    ori r17, (1<<GPIO_BTN_1_PRS) | (1<<GPIO_BTN_1_HLD)
    sbrc r16, GPIO_BTN_1                        ; if button is set, clear HLD flag
    cbr r17, (1<<GPIO_BTN_1_HLD)

    sts SREG_GPIO, r17

    pop r17
    pop r16
    reti


; --------------------------------------------------------------------------------
; ADC routines

; intializes ADC (THUMB_WHEEL_CHANNEL)
gpio_adc_init:
    ldi r16, ADC_MUX_SETTINGS | THUMB_WHEEL_CHANNEL      ; enable ADC channel
    out ADMUX, r16

    ldi r16, ADC_CTRL_A                       ; set clock prescaler
    out ADCSRA, r16

    ldi r16, ADC_CTRL_B                       ; set free-running mode
    out ADCSRB, r16

    sbi ADCSRA, ADEN                          ; turn on ADC
    sbi ADCSRA, ADSC                          ; start ADC conversion
    ret


; read ADC high byte into r16 (ADLAR = 1; 8 bit precision)
gpio_adc_read:
    in r16, ADCH
    ret
