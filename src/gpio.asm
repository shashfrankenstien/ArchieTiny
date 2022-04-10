.include "config.inc"                       ; LED_PIN and BTN1_PIN

; gpio mode, write and read registers
.equ    DDRB,               0x17
.equ    PORTB,              0x18
.equ	PINB,               0x16


; pin change interrupt control
.equ    GIMSK,              0x3b            ; GIMSK – General Interrupt Mask Register
.equ    PC_INT_ENABLE,      (1<<5)          ; bit 5 is PCIE (bit 6 is INT0 enable)

.equ    PCMSK,              0x15            ; PCMSK – Pin Change Mask Register - bits 0 through 5 enable PCINT 0 through 5



init_onboard_led:
    clr r16
    out PORTB, r16
    out DDRB, r16
    sbi DDRB, LED_PIN                ; setup output pin 1 (P1)
    ret


gpio_btn_init:
    ldi r16, PC_INT_ENABLE
    out GIMSK, r16

    sbi PORTB, BTN1_PIN
    cbi DDRB, BTN1_PIN

    ldi r16, (1<<BTN1_PIN)
    out PCMSK, r16
    clr r8
    ret


gpio_btn_press_isr:
    push r16
    push r20

    ; ldi r20, 0xff
    ; rcall time_delay_clock_cycles           ; software debouncing

    in r16, PINB
    sbrc r16, BTN1_PIN
    rjmp _pc_int_done

    sbrs r8, 0
    sbi PORTB, LED_PIN
    sbrc r8, 0
    cbi PORTB, LED_PIN
    ldi r16, 0xff
    eor r8, r16
_pc_int_done:
    pop r20
    pop r16
    reti

