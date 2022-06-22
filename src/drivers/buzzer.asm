.include "config.inc"                       ; BUZZER_PIN

; digital IO routines
buzzer_init:
    clr r16
    out PORTB, r16
    out DDRB, r16
    sbi DDRB, BUZZER_PIN                          ; setup output pin 1 (P1)
    ret
