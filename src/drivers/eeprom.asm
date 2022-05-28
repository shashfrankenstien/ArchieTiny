; interface to work with builtin EEPROM memory

; registers
.equ    EEARH,              0x1f                ; EEARH - EEPROM address register high byte (LSB is used only in ATTiny85)
.equ    EEARL,              0x1e                ; EEARL - EEPROM address register low byte
.equ    EEDR,               0x1d                ; EEDR – EEPROM data register
.equ    EECR,               0x1c                ; EECR – EEPROM control register


.equ    EEPROM_WRITE_MODE,  0b00000000          ; EEPM[1:0] (bits 4 and 5 of EECR): programming mode bits set to 0 means "atomic" erase and write mode

.equ    EEMPE,              2                   ; Bit 2 of EECR – EEMPE: EEPROM master program enable
.equ    EEPE,               1                   ; Bit 1 of EECR – EEPE: EEPROM Program Enable
.equ    EERE,               0                   ; Bit 0 – EERE: EEPROM Read Enable



; read a byte from builtin eeprom memory
; input
;   r25:r24    ; eeprom read address
; output
;   r16        ; byte read
eeprom_read:
    sbic EECR,EEPE                              ; wait for completion of previous writes
    rjmp eeprom_read

    out EEARH, r25                              ; set up address (r25:r24) in address register
    out EEARL, r24

    sbi EECR, EERE                              ; start EEPROM read by setting EERE

    in r16, EEDR                                ; read data from data register
    ret




; write a byte to builtin eeprom memory
; input
;   r25:r24    ; eeprom write address
;   r16        ; byte to write
eeprom_write:
    sbic EECR, EEPE                             ; wait for completion of any previous writes
    rjmp eeprom_write

    push r19
    ldi r19, EEPROM_WRITE_MODE                  ; set programming mode
    out EECR, r19

    out EEARH, r25                              ; set up address (r25:r24) in address register
    out EEARL, r24

    out EEDR, r16                               ; write data (r16) to data register
    sbi EECR,EEMPE                              ; write logical one to EEMPE (EEPROM master program enable)
    sbi EECR,EEPE                               ; start EEPROM write by setting EEPE
    pop r19
    ret



; update a byte in builtin eeprom memory
; - update does nothing if byte to write and byte at address are same
; - this conserves eeprom write cycles, but takes longer
; input
;   r25:r24    ; eeprom write address
;   r16        ; byte to write
eeprom_update:
    push r16
    push r19
    mov r19, r16

    rcall eeprom_read                           ; read byte at r25:r24
    cp r16, r19                                 ; compare with byte to write
    breq _eeprom_update_done                    ; if they are the same, return

    mov r16, r19
    rcall eeprom_write                          ; if they are not same, write new byte to eeprom

_eeprom_update_done:
    pop r19
    pop r16
    ret
