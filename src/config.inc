; config for ATtiny85

; intial RAM description
.equ    SRAM_START,     0x0060
.equ    SRAM_SIZE,      512
.equ    RAMEND,         0x025f

; blink config
.equ    LED_PIN,        1
.equ    LED_SOFT_DELAY,     250             ; custom software scaling limit - with current settings, the unit here is millisecond
                                            ; a value of 250 = 0.25 second


; time and delay manager
.equ    TIME_SOFT_COUNTER,   SRAM_START                 ; address to 24 bit software counter


; task manager table
.equ    TASK_TABLE_START,   TIME_SOFT_COUNTER + 3       ; Task vector start address
                                                        ; set this to TIME_SOFT_COUNTER + 3 since the time counter is 24 bits (3 bytes)
