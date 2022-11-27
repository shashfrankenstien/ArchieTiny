.include "config.inc"                       ; BUZZER_PIN


.if BUZZER_PIN - 1                  ; only PB1 (pysical pin 6) is currently supported for buzzer
    .err                            ; unsupported pin!
.endif


; timer / counter PWM control - Timer1
.equ    TCCR1,              0x30            ; TCCR1 – Timer/Counter1 Control Register

.equ    TCNT1,              0x2f            ; TCNT1 – Timer/Counter1 Register
.equ    OCR1A,              0x2e            ; OCR1A – Timer/Counter1 Output Compare RegisterA
.equ    OCR1C,              0x2d            ; OCR1C – Timer/Counter1 Output Compare RegisterC

.equ    PWM_CTRL,           0b01101001      ; PWM1A enabled, PB1 cleared on compare match. Set when TCNT1 = $00, prescaler at CK/256
                                            ; prescaled clock frequency is determined by bits [3:0] of PWM_CTRL byte

; per PWM_CTRL, while running Timer1 in PWM1A mode:
;   - a match on compare register A (OCR1A) triggers the PWM signal to go LOW
;   - a match on compare register C (OCR1C) triggers the PWM signal to go back HIGH
;
; PWM_COMPVAL_C controls the frequency / pitch
;   - with a 16MHz clock (CK), PWM counter frequency is set to CK/256 in PWM_CTRL
;   - PWM_COMPVAL_C acts as the PWM signal divider. so final frequency at the BUZZER_PIN (OC1A) will be CK/256/PWM_COMPVAL_C
;   - middle-C musical note (262 Hz) can thus be obtained by setting PWM_COMPVAL_C = 238
;       - 16000000 / 256 / 238 = 262.605
;       - or more generally, PWM_COMPVAL_C = lambda NOTE_FREQ: int(16000000 / 256 / NOTE_FREQ) ( value floored so as to make the notes slightly sharp )
.equ    BUZZ_NOTE_C4,       238             ; C4 (262 Hz)
.equ    BUZZ_NOTE_D4,       212             ; D4 (294 Hz)
.equ    BUZZ_NOTE_E4,       189             ; E4 (330 Hz)
.equ    BUZZ_NOTE_F4,       178             ; F4 (350 Hz)
.equ    BUZZ_NOTE_G4,       159             ; G4 (392 Hz)
.equ    BUZZ_NOTE_A4,       142             ; A4 (440 Hz)
.equ    BUZZ_NOTE_B4,       126             ; B4 (494 Hz)
;
.equ    BUZZ_NOTE_C5,       119             ; C5 (524 Hz)
.equ    BUZZ_NOTE_D5,       106             ; D5 (588 Hz)
.equ    BUZZ_NOTE_E5,       94              ; E5 (660 Hz)
.equ    BUZZ_NOTE_F5,       89              ; F5 (699 Hz)
.equ    BUZZ_NOTE_G5,       79              ; G5 (784 Hz)
.equ    BUZZ_NOTE_A5,       71              ; A5 (880 Hz)
.equ    BUZZ_NOTE_B5,       63              ; B5 (988 Hz)
;
.equ    BUZZ_NOTE_C6,       59              ; C6 (1047 Hz)
.equ    BUZZ_NOTE_D6,       53              ; D6 (1175 Hz)
.equ    BUZZ_NOTE_E6,       47              ; E6 (1319 Hz)
.equ    BUZZ_NOTE_F6,       44              ; F6 (1397 Hz)
.equ    BUZZ_NOTE_G6,       39              ; G6 (1568 Hz)
.equ    BUZZ_NOTE_A6,       35              ; A6 (1760 Hz)
.equ    BUZZ_NOTE_B6,       31              ; B6 (1976 Hz)
;
.equ    BUZZ_NOTE_C7,       29              ; C7 (2093 Hz)
.equ    BUZZ_NOTE_D7,       26              ; D7 (2350 Hz)
.equ    BUZZ_NOTE_E7,       23              ; E7 (2637 Hz)
.equ    BUZZ_NOTE_F7,       22              ; F7 (2794 Hz)
.equ    BUZZ_NOTE_G7,       19              ; G7 (3136 Hz)
.equ    BUZZ_NOTE_A7,       17              ; A7 (3520 Hz)
.equ    BUZZ_NOTE_B7,       15              ; B7 (3951 Hz)
;
.equ    BUZZ_NOTE_C8,       14              ; C8 (4186 Hz)
;
; PWM_COMPVAL_A controls volume
;   - PWM signal at BUZZER_PIN will be HIGH till counter reaches PWM_COMPVAL_A, then goes low till PWM_COMPVAL_C
;   - if signal stays HIGH for just as long as it stays LOW, volume is maximum (PWM_COMPVAL_A = PWM_COMPVAL_C / 2)
;   - PWM_COMPVAL_A can be varied between 0 and PWM_COMPVAL_C/2 to change volume


; buzzer_buzz takes note value (BUZZ_NOTE_*) in r16 and playes the note for 250 ms
buzzer_buzz:
    push r16
    push r20

    sbi DDRB, BUZZER_PIN            ; setup output pin 1 (PB1)

    out OCR1C, r16                  ; load compare C register with input BUZZ_NOTE_* value

    lsr r16                         ; load compare A register with 1/2 the value of OCR1C. This will ensure an even signal (max volume)
    out OCR1A, r16                  ; load compare A register

    ldi r16, PWM_CTRL
    out TCCR1, r16                  ; start PWM

    ldi r20, 150
    rcall timer_delay_ms_short      ; sleep for 250 ms

    clr r16
    out TCCR1, r22                  ; stop PWM
    cbi DDRB, BUZZER_PIN            ; disable output pin 1 (PB1)

    pop r20
    pop r16
    ret
