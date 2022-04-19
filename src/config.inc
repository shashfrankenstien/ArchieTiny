; config for ATtiny85

; intial RAM description
.equ    SRAM_START,         0x0060
.equ    SRAM_SIZE,          512
.equ    RAMEND,             0x025f


; time and delay manager
.equ    TIME_SOFT_COUNTER,   SRAM_START                 ; address to 24 bit software counter

; resource status / utility registers
.equ    SREG_I2C,           TIME_SOFT_COUNTER + 3       ; set this to TIME_SOFT_COUNTER + 3 since the time counter is 24 bits (3 bytes)
.equ    SREG_OLED,          SREG_I2C + 1
.equ    SREG_GPIO_PC,       SREG_OLED + 1
; ADC utility
.equ    ADC_CHAN_0_VAL,     SREG_GPIO_PC + 1

; task manager table
.equ    TASK_TABLE_START,   ADC_CHAN_0_VAL + 1          ; Task vector start address
.equ    TASK_STACK_SIZE,    100                         ; Each task in the task manager get TASK_STACK_SIZE bytes of RAM
                                                        ;   some of these bytes are required for the task manager and the rest are available for the task
.equ    TASK_MAX_TASKS,     4




; gpio config
.equ    LED_PIN,            1
.equ    GPIO_BTN_0,         3
.equ    GPIO_BTN_1,         4
.equ    ADC_CHAN_0,         0


; ADC voltage divider buttons
.equ    ADC_VD_BTNS_CHAN,   ADC_CHAN_0
.equ    ADC_VD_BTNS_VAL,    ADC_CHAN_0_VAL



; ADC voltage divider value calculation (RESET pin)
;     - tested on RESET pin (internal pull up resistance (R1))
;     - because we're using the reset pin, input voltage cannot be below ~1.3 v (documentation says 0.9 v :/)

;     - equations (only care about 8 MSB precision)
;         - VOUT = lambda VIN, R1, R2: VIN * R2/(R1+R2)
;         - ADC_VAL = lambda VREF, VOUT: int((VOUT * 1024) / VREF) >> 2

;     - approx measured / fudged values that worked out in tests
;         - VREF = Vcc = 2.8 v
;         - VIN = Vpin = 2.6 v
;         - R2 = RESET pin pull-up = 50 kilo ohm aprox (??)

; ADC button    | Resistance (R2) | Voltage | ADC threshold (8 MSB precision)
; --------------|-----------------|---------|--------------
; ADC_VD_BTN_0  | 51 K            | 1.313 v | 0b01111000
; ADC_VD_BTN_1  | 100 K           | 1.733 v | 0b10011110
; ADC_VD_BTN_2  | 220 K           | 2.118 v | 0b11000001
; ADC_VD_BTN_3  | 300 K           | 2.229 v | 0b11001011
; ADC_VD_BTN_4  | 1 M             | 2.476 v | 0b11100010




.equ    ADC_VD_BTN_0,       0                            ; bit corresponding to button 0
.equ    ADC_VD_BTN_1,       1                            ; bit corresponding to button 1
.equ    ADC_VD_BTN_2,       2                            ; bit corresponding to button 2
.equ    ADC_VD_BTN_3,       3                            ; bit corresponding to button 3
.equ    ADC_VD_BTN_4,       4                            ; bit corresponding to button 4

.equ    ADC_VD_BTN_0_TRESH, 0b01111000                   ; ADC threshold for button 0
.equ    ADC_VD_BTN_1_TRESH, 0b10011110                   ; ADC threshold for button 1
.equ    ADC_VD_BTN_2_TRESH, 0b11000001                   ; ADC threshold for button 2
.equ    ADC_VD_BTN_3_TRESH, 0b11001011                   ; ADC threshold for button 3
.equ    ADC_VD_BTN_4_TRESH, 0b11100010                   ; ADC threshold for button 4
