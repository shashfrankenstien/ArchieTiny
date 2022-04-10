; General registers / addresses

.include "config.inc"


.equ    SPL,                0x3d
.equ    SPH,                0x3e
.equ    SREG,               0x3f


; timer / counter control - Timer0
; .equ    GTCCR,            0x2c            ; GTCCR – General Timer/Counter Control Register
.equ    TCCR0A,             0x2a            ; TCCR0A – Timer/Counter Control Register A
.equ    TCCR0B,             0x33            ; TCCR0B – Timer/Counter Control Register B
.equ    OCR0A,              0x29            ; OCR0A – Output Compare Register A
.equ    OCR0B,              0x28            ; OCR0B – Output Compare Register B
.equ    TCNT0,              0x32            ; TCNT0 – Timer/Counter Register
.equ    TIMSK,              0x39            ; TIMSK – Timer/Counter Interrupt Mask Registe
.equ    TIFR,               0x38            ; TIFR – Timer/Counter Interrupt Flag Register

.equ    COUNTER_CTRL_A,     0b00000010      ; mode - 10 = Clear Timer on Compare Match (CTC) mode - resets counter when compare matches OCR0A
.equ    COUNTER_CTRL_B,     0b00000011      ; clk setting (011 = 16 MHz / 64)

.equ    OCIE0A,             4               ; OCIE0A (Output Compare Interrupt Enable - Timer 0 - A) is the 4th bit of TIMSK
.equ    OCIE0B,             3               ; OCIE0B (Output Compare Interrupt Enable - Timer 0 - B) is the 3rd bit of TIMSK
.equ    TIMER_INT_MASK,     (1<<OCIE0A) | (1<<OCIE0B)   ; Timer 0 compare match A & B interrupts enabled

.equ    TIMER_COMPVAL_A,    250             ; using compare match A interrupt, timer counts from 0 to TIMER_COMPVAL_A, then resets to 0
                                            ; TIMER_COMPVAL_A value 250 = 1 millisecond
                                            ; this was arrived at using the below equation
                                            ; TIMER_COMPVAL_A = 0.001 * f_cpu / prescale_div
                                            ; if f_cpu = 16 MHz and selected prescale_div = 64, TIMER_COMPVAL_A = 250

.equ    TIMER_COMPVAL_B,    150             ; compare match B interrupt is triggered when TCNT0 reaches this value
                                            ; however, this interrupt will not reset the counter. It will always count up to TIMER_COMPVAL_A
                                            ; hence, the compare match B interrupt has the same frequency as compare match A


; built-in LED control
.equ    DDRB,               0x17
.equ    PORTB,              0x18
.equ	PINB,               0x16


; repurpose r25 for gpio flags
; .req    r25,            r25


; settings to read fuse bits
.equ    SPMCSR,           0x37            ; SPMCSR - Store Program Memory Control and Status Register
.equ    RFLB,             3               ; bit 3 allows reading fuse and lock bits
.equ    SPMEN,            0               ; bit 0 enable program memory control



; MAIN PROGRAM

.org 0                              ; origin - address of next statement
; interrupt vector table
rjmp main                           ; address 0x0000 - RESET
reti                                ; address 0x0001 - INT0_ISR
reti                                ; address 0x0002 - PCINT0_ISR
reti                                ; address 0x0003 - TIM1_COMPA_ISR
reti                                ; address 0x0004 - TIM1_OVF_ISR
reti                                ; address 0x0005 - TIM0_OVF_ISR
reti                                ; address 0x0006 - EE_RDY_ISR
reti                                ; address 0x0007 - ANA_COMP_ISR
reti                                ; address 0x0008 - ADC_ISR
reti                                ; address 0x0009 - TIM1_COMPB_ISR
rjmp time_tick_isr                  ; address 0x000A - TIM0_COMPA_ISR
rjmp taskmanager_exec_next_isr      ; address 0x000B - TIM0_COMPB_ISR
reti                                ; address 0x000C - WDT_ISR
reti                                ; address 0x000D - USI_START_ISR
reti                                ; address 0x000E - USI_OVF_ISR



init_timer0:
    ldi r16, COUNTER_CTRL_A
    out TCCR0A, r16                 ; mode select

    ldi r16, COUNTER_CTRL_B
    out TCCR0B, r16                 ; clk select

    ldi r16, TIMER_COMPVAL_A
    out OCR0A, r16                  ; load compare A register

    ldi r16, TIMER_COMPVAL_B
    out OCR0B, r16                  ; load compare B register

    ldi r16, TIMER_INT_MASK
    out TIMSK, r16                  ; enable interrupt
    ret


init_onboard_led:
    sbi DDRB, LED_PIN                ; setup output pin 1 (P1)
    sbi DDRB, LED_PIN2               ; setup output pin 1 (P1)
    out PORTB, 0
    ret



main:                               ; initialize
    cli
    ldi r16, lo8(RAMEND)            ; set stack pointer low bits to low(RAMEND)
    out SPL, r16
    ldi r16, hi8(RAMEND)            ; set stack pointer high bits to high(RAMEND)
    out SPH, r16

    rcall init_timer0               ; set timer / counter options
    rcall init_onboard_led          ; set LED output pin

    rcall time_init
    rcall i2c_init
    rcall oled_init

    rcall taskmanager_init              ; initialize task manager table

    ldi r17, hi8(test3)                 ; add test3 task to task manager table
    ldi r16, lo8(test3)
    rcall taskmanager_add

    ldi r17, hi8(blink_old)             ; add blink task to task manager table
    ldi r16, lo8(blink_old)
    rcall taskmanager_add

    sei

pool:
    sleep                               ; wait for interrupts (required for simavr to perform correctly. good idea anyway)
    rjmp pool





blink_old:
    ldi r20, 0xe8                           ; set delay to approximately 1 second (250 * 4 milliseconds)
    ldi r21, 0x03
    clr r22

    ldi r16, 0xff                           ; oled fill byte
blink_loop:
    ; sbi PORTB, LED_PIN
    rcall time_delay_ms
    sbi PORTB, LED_PIN
    rcall test_oled
    dec r16

    ; rcall time_delay_ms
    ; rcall test_oled_read

    ; rcall time_delay_ms
    ; sbi PORTB, LED_PIN
    ; rcall test_oled2

    ; rcall time_delay_ms
    ; rcall test_oled_read

    rjmp blink_loop



test3:
    ldi r20, 0xfa                           ; set delay to 0.25 second (250 milliseconds)
    clr r21
    clr r22
test3_loop:
    sbi PORTB, LED_PIN2
    rcall time_delay_ms
    cbi PORTB, LED_PIN2
    rcall time_delay_ms
    rjmp test3_loop
