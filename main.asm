
; General registers / addresses
; .equ	INT0addr,       0x0001	; External Interrupt 0
; .equ	PCI0addr,       0x0002	; Pin change Interrupt Request 0
; .equ	OC1Aaddr,       0x0003	; Timer/Counter1 Compare Match 1A
; .equ	OVF1addr,       0x0004	; Timer/Counter1 Overflow
; .equ	OVF0addr,       0x0005	; Timer/Counter0 Overflow
; .equ	ERDYaddr,       0x0006	; EEPROM Ready
; .equ	ACIaddr,        0x0007	; Analog comparator
; .equ	ADCCaddr,       0x0008	; ADC Conversion ready
; .equ	OC1Baddr,       0x0009	; Timer/Counter1 Compare Match B
; .equ	OC0Aaddr,       0x000a	; Timer/Counter0 Compare Match A
; .equ	OC0Baddr,       0x000b	; Timer/Counter0 Compare Match B
; .equ	WDTaddr,        0x000c	; Watchdog Time-out
; .equ	USI_STARTaddr,  0x000d	; USI START
; .equ	USI_OVFaddr,    0x000e	; USI Overflow


.equ	SRAM_START,     0x0060
.equ	SRAM_SIZE,      512
.equ	RAMEND,         0x025f


.equ	SPL,            0x3d
.equ	SPH,            0x3e
.equ	DDRB,           0x17
.equ	PORTB,          0x18


.equ LED_PIN, 1


.org 0  ; origin

.global main                        ; micronucleus bootloader calls this (required for digispark micronucleus)
main:                               ; initialize

    ldi r16, lo8(RAMEND)            ; set stack pointer low bits to low(RAMEND)
    out SPL, r16
    ldi r16, hi8(RAMEND)            ; set stack pointer high bits to high(RAMEND)
    out SPH, r16

    sbi DDRB, LED_PIN               ; setup output pin 1 (P1)


loop:
    sbi PORTB, LED_PIN
    rcall delay
    cbi PORTB, LED_PIN
    rcall delay
    rjmp loop


delay:
    ldi r16, 0xff
    ldi r17, 0xff
    ldi r18, 0x0f

delay2:
    dec r16
    brne delay2
    ldi r16, 0xff
    dec r17
    brne delay2
    ldi r17, 0xff
    dec r18
    brne delay2
    ret
