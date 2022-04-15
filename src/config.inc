; config for ATtiny85

; intial RAM description
.equ    SRAM_START,     0x0060
.equ    SRAM_SIZE,      512
.equ    RAMEND,         0x025f

; blink config
.equ    LED_PIN,        1
.equ    BTN1_PIN,       3
.equ    THUMB_WHEEL_CHANNEL, 0

; time and delay manager
.equ    TIME_SOFT_COUNTER,   SRAM_START                 ; address to 24 bit software counter

; resource status registers
.equ    SREG_I2C,           TIME_SOFT_COUNTER + 3       ; set this to TIME_SOFT_COUNTER + 3 since the time counter is 24 bits (3 bytes)
.equ    SREG_OLED,          SREG_I2C + 1
.equ    SREG_GPIO,          SREG_OLED + 1

; task manager table
.equ    TASK_TABLE_START,   SREG_GPIO + 1               ; Task vector start address
.equ    TASK_STACK_SIZE,    100                         ; Each task in the task manager get TASK_STACK_SIZE bytes of RAM
                                                        ;   some of these bytes are required for the task manager and the rest are available for the task
.equ    TASK_MAX_TASKS,     4

