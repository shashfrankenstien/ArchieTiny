; config for ATtiny85

; intial RAM description
.equ    SRAM_START,         0x0060
.equ    SRAM_SIZE,          512
.equ    RAMEND,             0x025f
; -------------------------------------------------

; time and delay manager
.equ    TIME_SOFT_COUNTER,   SRAM_START                 ; address to 24 bit software counter

; resource status / utility registers
.equ    SREG_I2C,           TIME_SOFT_COUNTER + 3       ; set this to TIME_SOFT_COUNTER + 3 since the time counter is 24 bits (3 bytes)
.equ    SREG_OLED,          SREG_I2C + 1
.equ    SREG_GPIO_PC,       SREG_OLED + 1
.equ    SREG_ADC_VD_HLD,    SREG_GPIO_PC + 1
; ADC utility
.equ    ADC_CHAN_0_VAL,     SREG_ADC_VD_HLD + 1

; task manager table
.equ    TASK_TABLE_START,   ADC_CHAN_0_VAL + 1          ; Task vector start address
.equ    TASK_STACK_SIZE,    100                         ; Each task in the task manager get TASK_STACK_SIZE bytes of RAM
                                                        ;   some of these bytes are required for the task manager and the rest are available for the task
.equ    TASK_MAX_TASKS,     4


; -------------------------------------------------

; gpio config
.equ    LED_PIN,            1
.equ    GPIO_BTN_0,         3
.equ    GPIO_BTN_1,         4
.equ    ADC_CHAN_0,         0


; -------------------------------------------------
; ADC voltage divider buttons
.equ    ADC_VD_BTNS_CHAN,   ADC_CHAN_0
.equ    ADC_VD_BTNS_VAL,    ADC_CHAN_0_VAL


; ADC voltage divider value calculation (RESET pin)
;     - tested on RESET pin (internal pull up resistance R1)
;     - because we're using the reset pin, input voltage cannot be below ~1.3 v (documentation says 0.9 v :/)

;     - equations (only care about 8 MSB precision)
;         - VOUT = lambda VIN, R1, R2: VIN * R2/(R1+R2)
;         - ADC_VAL = lambda VREF, VOUT: int((VOUT * 1024) / VREF) >> 2

;     - approx measured / fudged values that worked out in tests
;         - VREF = Vcc = 2.78 v
;         - VIN = Vpin = 2.42 v
;         - R2 = RESET pin pull-up = 50 kilo ohm aprox (guess??)
;
; - We set the threshold to be a few counts above these values

; ADC button    | Resistance (R2) | Voltage | ADC threshold (8 MSB precision)
; --------------|-----------------|---------|--------------
; ADC_VD_BTN_0  | 51 K            | 1.222 v | 0b01110000
; ADC_VD_BTN_1  | 68 K            | 1.395 v | 0b10000000
; ADC_VD_BTN_2  | 100 K           | 1.613 v | 0b10010100
; ADC_VD_BTN_3  | 300 K           | 2.074 v | 0b10111111
; ADC_VD_BTN_4  | 1 M             | 2.305 v | 0b11010100


.equ    ADC_VD_BTN_0,       0                            ; bit corresponding to button 0
.equ    ADC_VD_BTN_1,       1                            ; bit corresponding to button 1
.equ    ADC_VD_BTN_2,       2                            ; bit corresponding to button 2
.equ    ADC_VD_BTN_3,       3                            ; bit corresponding to button 3
.equ    ADC_VD_BTN_4,       4                            ; bit corresponding to button 4

.equ    ADC_VD_BTN_0_TRESH, 0b01110000 + 16               ; ADC threshold for button 0
.equ    ADC_VD_BTN_1_TRESH, 0b10000000 + 16               ; ADC threshold for button 1
.equ    ADC_VD_BTN_2_TRESH, 0b10010100 + 16               ; ADC threshold for button 2
.equ    ADC_VD_BTN_3_TRESH, 0b10111111 + 16               ; ADC threshold for button 3
.equ    ADC_VD_BTN_4_TRESH, 0b11010100 + 16               ; ADC threshold for button 4

; -------------------------------------------------
; Reading button presses (Software stabilization)
;     - ADC clock speed is clk / 128. for clk = 16 MHz, ADC clock speed will be 125 kHz
;     - ADC generally takes about 13 - 15 ADC clocks to perform a conversion.
;     - Let's approx to 14 which gives us a conversion frequency of ~9 kHz (i.e. once every ~110 micro seconds)
;     - We're using a 680 pF capacitor against 50 k ohm internal pull-up (RESET pin) for smoothing. So, time to charge up to 63% is (50 * 10**3 * 681 * 10**-12) = 34 micro seconds (TAO).
;         We might read a wrong value during this charge / discharge time. We can assume that the capacitor will be reasonably full at 5 * TAO
;     - Given the ADC conversion period (110 micro seconds), we should make sure multiple readings are within threshold to confirm a button press
;     - To be absolutely safe, we can take a bunch of readings waiting a few ms between them; report a press only if all the readings pass the same threshold

.equ    ADC_BTN_NUM_RE_READS,      20
.equ    ADC_BTN_RE_READ_INTERVAL,  3           ; milli seconds
; -------------------------------------------------
