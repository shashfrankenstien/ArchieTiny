.include "config.inc"                       ; LED_PIN, BTN1_PIN, THUMB_WHEEL_CHANNEL

; gpio mode, write and read registers
.equ    DDRB,               0x17
.equ    PORTB,              0x18
.equ	PINB,               0x16


; pin change interrupt control
.equ    GIMSK,              0x3b            ; GIMSK – General Interrupt Mask Register
.equ    PC_INT_ENABLE,      (1<<5)          ; bit 5 is PCIE (bit 6 is INT0 enable)

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

; --------------------------------------------------------------------------------

; digital IO routines
init_onboard_led:
    clr r16
    out PORTB, r16
    out DDRB, r16
    sbi DDRB, LED_PIN                ; setup output pin 1 (P1)
    ret


; intialize PC interrupt
; - inputs are set to active high by enabling pull-up registers
gpio_btn_init:
    ldi r16, PC_INT_ENABLE
    out GIMSK, r16

    sbi PORTB, BTN1_PIN
    cbi DDRB, BTN1_PIN

    ldi r16, (1<<BTN1_PIN)
    out PCMSK, r16
    clr r9
    ret


; handle PC interrupt
; - this isr has software check to only trigger on falling edge??
; - assumes that debouncing is handled by hardware (simple RC circuit. schmitt trigger may be overkill)
gpio_btn_press_isr:
    push r16
    push r20

    ; ldi r20, 0xff
    ; rcall time_delay_clock_cycles           ; software debouncing

    in r16, PINB
    sbrc r16, BTN1_PIN
    rjmp _pc_int_done

    sbrs r9, 0
    sbi PORTB, LED_PIN
    sbrc r9, 0
    cbi PORTB, LED_PIN
    ldi r16, 0xff
    eor r9, r16
_pc_int_done:
    pop r20
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
