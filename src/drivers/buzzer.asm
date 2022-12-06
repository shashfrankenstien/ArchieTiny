; piezo buzzer for audio
.include "config.inc"                       ; BUZZER_VOLUME_REG, BUZZER_PIN


.if BUZZER_PIN - 1                          ; only PB1 (pysical pin 6) is currently supported for buzzer
    .error "BUZZER_PIN - unsupported pin!"
.endif


; timer / counter PWM control - Timer1
.equ    TCCR1,              0x30            ; TCCR1 – Timer/Counter1 Control Register

.equ    TCNT1,              0x2f            ; TCNT1 – Timer/Counter1 Register
.equ    OCR1A,              0x2e            ; OCR1A – Timer/Counter1 Output Compare RegisterA
.equ    OCR1C,              0x2d            ; OCR1C – Timer/Counter1 Output Compare RegisterC

.equ    PWM_CTRL,           0b01101001      ; PWM1A enabled; PB1 cleared on compare match and set when TCNT1=0; prescaler at CK/256
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
;       - or more generally, PWM_COMPVAL_C = lambda NOTE_FREQ: int(16000000 / 256 / NOTE_FREQ)
;       - ( value floored so as to make the notes slightly sharp )
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


; BUZZER_VOLUME_REG (1)
;   - buzzer volume register holds current volume level in 4 low bits [3:0] - can be set using buzzer_set_volume routine
;   - it also has a flag to indicate if buzzer is muted (bit 7)
;      -----------------------------------------------------------------------------------------------
;      |  BUZZ_MUTE  |  N/A  |  N/A  |  N/A  |  BUZZ_VOL3  |  BUZZ_VOL2  |  BUZZ_VOL1  |  BUZZ_VOL0  |
;      -----------------------------------------------------------------------------------------------
.equ    BUZZ_MUTE_BIT,      7




buzzer_init:
    ldi r16, 10
    rcall buzzer_set_volume
    ret


; buzzer_set_volume takes volume value in r16
;   - supported values are between 0 and 15
;   - has the effect of unmuting by clearing BUZZ_MUTE_BIT
buzzer_set_volume:
    andi r16, 0b00001111            ; only keep low 4 bits (0 to 15)
    sts BUZZER_VOLUME_REG, r16      ; set BUZZER_VOLUME_REG
    ret


; buzzer_toggle_mute toggles the BUZZ_MUTE_BIT bit in BUZZER_VOLUME_REG
;  - returns non-zero for muted and 0 for unmuted in r16
buzzer_toggle_mute:
    push r17
    lds r16, BUZZER_VOLUME_REG      ; read current volume register

    ldi r17, (1<<BUZZ_MUTE_BIT)     ; toggle mute bit
    eor r16, r17
    sts BUZZER_VOLUME_REG, r16      ; set BUZZER_VOLUME_REG
    pop r17
    andi r16, 0b10000000            ; r16 is returned as non-zero if muted
    ret



; internal_buzzer_set_pwm_compare_A sets compare match A to a proportional value based on volume
; - takes note value (compare match C) in r16
; - takes volume level in r17 - scales volume from (0 to 15) to (1 to r16/2)
;   - this is done by -> (r16 / 2) * (r17 / 15)
internal_buzzer_set_pwm_compare_A:
    push r18

    lsr r16                         ; (r16 / 2)
    rcall mul8                      ; (r16 / 2) * r17

    ; r17:r16 contains a likely 16 bit result. this can be divided by 15 like below
    ;   - (MSB * 256 / 15) + (LSB / 15)
    push r16                    ; save LSB for later
    mov r16, r17                ; get MSB in r16
    ldi r17, (256 / 15)
    rcall mul8                  ; (MSB * 256 / 15)
    mov r18, r16                ; result will be less than 256. save in r18

    pop r16                     ; restore previous LSB
    ldi r17, 15
    rcall div8                  ; (LSB / 15)

    add r16, r18                ; (MSB * 256 / 15) + (LSB / 15) or rather, (r16 / 2) * (r17 / 15)

    cpi r16, 1                  ; minimum allowed value is 1 (this will be used if output value is 0)
    brsh _buzzer_set_pwm_compare_A_ok
    ldi r16, 1
_buzzer_set_pwm_compare_A_ok:
    out OCR1A, r16                  ; load compare A register

    pop r18
    ret


; buzzer_play_note_start starts playing the note (one of BUZZ_NOTE_*) provided in r16
; plays note until buzzer_play_note_stop is called
; clears r16 before return indicating note being consumed - just convenient to eliminate pushing to stack :P
buzzer_play_note_start:
    push r17
    lds r17, BUZZER_VOLUME_REG      ; read current volume level

    sbrc r17, BUZZ_MUTE_BIT         ; check if buzzer is muted
    rjmp _buzzer_play_note_start_done

    andi r17, 0b00001111            ; only keep low 4 bits (0 to 15)
    tst r17                         ; check if volume is set to 0 (mute)
    breq _buzzer_play_note_start_done

    sbi DDRB, BUZZER_PIN            ; setup output pin 1 (PB1)

    out OCR1C, r16                  ; load compare C register with input BUZZ_NOTE_* value
    rcall internal_buzzer_set_pwm_compare_A ; uses r16 and r17 to set OCR1A

    ldi r16, PWM_CTRL
    out TCCR1, r16                  ; start PWM

_buzzer_play_note_start_done:
    clr r16                         ; return 0 in r16 - just convenient to eliminate pushing to stack :P
    pop r17
    ret


; stops PWM and consequently ends any playing note
buzzer_play_note_stop:
    clr r16
    out TCCR1, r16                  ; stop PWM
    cbi DDRB, BUZZER_PIN            ; disable output pin 1 (PB1)
    ret




; buzzer melody format
; ---------------------------
; buzzer_macro_play_melody takes 2 arguments
;   - tempo in milliseconds (1 unit of duration to play a note)
;   - melody a sequence of pairs => a note, and duration units to play the note
;
; example usage
;   - buzzer_macro_play_melody 250 C4 1 D4 1 E4 2 D4 1 C4 1

.macro buzzer_macro_play_melody tempo=150, melody:vararg
    push r16
    push r20
    ldi r20, \tempo
    internal_buzzer_macro_play_melody \melody
    pop r20
    pop r16
.endm

; this internally used macro recursively processes note and duration unit pairs for a given melody
.macro internal_buzzer_macro_play_melody note, ntimes, remaining:vararg
    ldi r16, BUZZ_NOTE_\note
    rcall buzzer_play_note_start
    .rept  \ntimes
        rcall timer_delay_ms_short
    .endr
    rcall buzzer_play_note_stop
    .ifnb \remaining
        internal_buzzer_macro_play_melody \remaining
    .endif
.endm




; buzzer_nav_click produces a very short click-like beep. can be used for navigation feedback
buzzer_nav_click:
    buzzer_macro_play_melody 10 C7 1
    ret
