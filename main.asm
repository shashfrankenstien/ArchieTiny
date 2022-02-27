; General registers / addresses

.equ	SRAM_START,     0x0060
.equ	SRAM_SIZE,      512
.equ	RAMEND,         0x025f

.equ	SPL,            0x3d
.equ	SPH,            0x3e
.equ    SREG,           0x3f

; built-in LED control
.equ	DDRB,           0x17
.equ	PORTB,          0x18
.equ    LED_PIN,        1


; timer / counter control
; .equ    GTCCR,          0x2C        ; GTCCR – General Timer/Counter Control Register
.equ    TCCR0A,         0x2A        ; TCCR0A – Timer/Counter Control Register A
.equ    TCCR0B,         0x33        ; TCCR0B – Timer/Counter Control Register B
.equ    OCR0A,          0x29        ; OCR0A – Output Compare Register A
.equ    TNCT0,          0x32        ; TCNT0 – Timer/Counter Register
.equ    TIMSK,          0x39        ; TIMSK – Timer/Counter Interrupt Mask Registe
.equ    TIFR,           0x38        ; TIFR – Timer/Counter Interrupt Flag Register

.equ    COUNTER_CTRL_A,    0b00000010   ; mode - 10 = Clear Timer on Compare Match (CTC) mode
.equ    COUNTER_CTRL_B,    0b00000101   ; clk setting (101 = 16.5 MHz / 1024)
.equ    TIMER_INT_MASK,    0b00010000   ; Timer 0 compare match A interrupt

.equ    TIMER_COMPVAL_A,   16           ; timer counts from 0 to TIMER_COMPVAL_A, then resets to 0
                                        ; TIMER_COMPVAL_A value 16 = 1 millisecond
                                        ; this was arrived at using the below equation
                                        ; TIMER_COMPVAL_A = 0.001 * f_cpu / prescale_div
                                        ; if f_cpu = 16.5 MHz and selected prescale_div = 1024, TIMER_COMPVAL_A ~ 16


; custom special purpose registers

; repurpose r25 for custom flags
; .def    aflags,         r25


; MAIN PROGRAM

.org 0                              ; origin - address of next statement
; interrupt vector table
rjmp main                           ; Address 0x0000 - RESET
reti                                ; Address 0x0001 - INT0_ISR
reti                                ; Address 0x0002 - PCINT0_ISR
reti                                ; Address 0x0003 - TIM1_COMPA_ISR
reti                                ; Address 0x0004 - TIM1_OVF_ISR
reti                                ; Address 0x0005 - TIM0_OVF_ISR
reti                                ; Address 0x0006 - EE_RDY_ISR
reti                                ; Address 0x0007 - ANA_COMP_ISR
reti                                ; Address 0x0008 - ADC_ISR
reti                                ; Address 0x0009 - TIM1_COMPB_ISR
rjmp timer0_isr                     ; Address 0x000A - TIM0_COMPA_ISR
reti                                ; Address 0x000B - TIM0_COMPB_ISR
rjmp ohno                           ; Address 0x000C - WDT_ISR
reti                                ; Address 0x000D - USI_START_ISR
reti                                ; Address 0x000E - USI_OVF_ISR



main:                               ; initialize
    cli
    ; set stack pointer
    ldi r16, lo8(RAMEND)            ; set stack pointer low bits to low(RAMEND)
    out SPL, r16
    ldi r16, hi8(RAMEND)            ; set stack pointer high bits to high(RAMEND)
    out SPH, r16

    ; set LED output pin
    sbi DDRB, LED_PIN               ; setup output pin 1 (P1)
    out PORTB, 0
    ldi r25, LED_PIN

    ; set timer / counter options
    ldi r16, COUNTER_CTRL_A
    out TCCR0A, r16                  ; mode select

    ldi r16, COUNTER_CTRL_B
    out TCCR0B, r16                  ; clk select

    ldi r16, TIMER_COMPVAL_A
    out OCR0A, r16

    ldi r16, TIMER_INT_MASK
    out TIMSK, r16                  ; enable interrupt

    clr r20             ; custom scaling on timer
    ldi r21, 250        ; custom scaling limit - with current settings, the unit here is millisecond
                        ; a value of 250 = 0.25 second
    sei

pool:
    sleep
    rjmp pool



timer0_isr:
    inc r20
    cpse r20, r21
    reti
    clr r20
timer0_scaled:
    sbrc r25, LED_PIN-1         ; if value is unset, continue to "on", else unset it in the "off" label
    rjmp off
on:
    sbi PORTB, LED_PIN              ; set bit
    sbr r25, LED_PIN
    reti
off:
    cbi PORTB, LED_PIN              ; clear bit
    cbr r25, LED_PIN
    reti



ohno:
    reti
