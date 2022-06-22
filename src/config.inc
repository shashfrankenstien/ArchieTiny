; config for ATtiny85

; intial RAM description
.equ    SRAM_START,         0x0060
.equ    SRAM_SIZE,          512
.equ    RAMEND,             0x025f
; -------------------------------------------------

; time and delay manager
.equ    TIME_SOFT_COUNTER,         SRAM_START                 ; address to 24 bit software counter

; -------------------------------------------------
; resource status / utility registers
.equ    SREG_I2C,                 TIME_SOFT_COUNTER + 3       ; set this to TIME_SOFT_COUNTER + 3 since the time counter is 24 bits (3 bytes)
.equ    SREG_OLED,                SREG_I2C + 1
.equ    SREG_GPIO_PC,             SREG_OLED + 1
.equ    SREG_ADC_VD_HLD,          SREG_GPIO_PC + 1
; ADC utility
.equ    ADC_CHAN_0_VAL,           SREG_ADC_VD_HLD + 1
.equ    ADC_CHAN_1_VAL,           ADC_CHAN_0_VAL + 1

; console utility
.equ    TEXTMODE_CURSOR_PAGE,     ADC_CHAN_1_VAL + 1          ; byte to track text-mode page address
.equ    TEXTMODE_CURSOR_COL,      TEXTMODE_CURSOR_PAGE + 1    ; byte to track text-mode column address


; -------------------------------------------------
; task manager table
.equ    TASK_RAM_START,           TEXTMODE_CURSOR_COL + 1     ; Task vector start address

.equ    TASK_STACK_SIZE,          100                         ; Each task in the task manager get TASK_STACK_SIZE bytes of RAM
.equ    TASK_MAX_TASKS,           2                           ;   some of these bytes are required for the task manager and the rest are available for the task


; task manager calculated constants. see tasks.asm for description
.equ    TASKCTS,               TASK_RAM_START                 ; task counter and status register
.equ    TASKPTR,               TASKCTS + 1                    ; current task index

.equ    TASK_SP_VECTOR,        TASKPTR + 1                          ; task stack pointers vector (each pointer is 2 bytes)
.equ    TASK_STACKS_TOP,       TASK_SP_VECTOR + (TASK_MAX_TASKS*2)  ; start of task stacks
.equ    TASK_STACKS_BOTTOM,    TASK_STACKS_TOP + (TASK_STACK_SIZE * TASK_MAX_TASKS)   ; end of task stacks

.equ    TASK_RAM_END,          TASK_STACKS_BOTTOM             ; alias




; -------------------------------------------------
; heap! - dynamic internal memory management (malloc) - see lib/mem.asm for more description

.equ    FREE_RAM_START,        TASK_RAM_END
.equ    FREE_RAM_END,          (RAMEND - 8)                   ; leave out 8 bytes at the end since that is our original stack


.equ    MALLOC_FREE_RAM,       FREE_RAM_END - FREE_RAM_START
.iflt 256 - MALLOC_FREE_RAM                                   ; if more than 256 bytes of memory is free, default to 256 so that we can use 8 bit pointer addressing
    .equ    MALLOC_FREE_RAM,   256                            ; address overflow!
.endif


.equ    MALLOC_BLOCK_SIZE,     8
.equ    MALLOC_MAX_BLOCKS,     (MALLOC_FREE_RAM / (MALLOC_BLOCK_SIZE + 1))  ; look for space for 1 additional byte for the malloc table
.equ    MALLOC_TABLE_SIZE,     MALLOC_MAX_BLOCKS

; error handling for 0 MALLOC_MAX_BLOCKS
.ifle MALLOC_MAX_BLOCKS
    .err                            ; no malloc-able blocks. check task manager memory allocation
.endif

; error handling for MALLOC_MAX_BLOCKS greater than 250 (never gonna happen since MALLOC_FREE_RAM is restricted to 256, but whatever)
.iflt 250 - MALLOC_MAX_BLOCKS       ; test if 250 - MALLOC_MAX_BLOCKS is less than 0
    .err                            ; address overflow!
.endif

.equ    MALLOCFREECTR,                   FREE_RAM_START       ; 1 byte

.equ    MALLOC_RAM_START,                MALLOCFREECTR
.equ    MALLOC_TABLE_START,              MALLOCFREECTR + 1
.equ    MALLOC_TABLE_END,                MALLOC_TABLE_START + MALLOC_TABLE_SIZE
.equ    MALLOC_RAM_END,                  MALLOC_TABLE_END + (MALLOC_BLOCK_SIZE * MALLOC_MAX_BLOCKS)


; error handling for overflow
.ifle ((RAMEND - 8) - MALLOC_RAM_END)
    .err                            ; memory overflow!
.endif

; -------------------------------------------------



.equ    EEPROM_SIZE,            512                          ; bytes
.equ    EEPROM_RESERVED_SIZE,   5


.equ    FS_FREE_SIZE,           EEPROM_SIZE - EEPROM_RESERVED_SIZE
.equ    FS_CLUSTER_SIZE,        20
.equ    FS_MAX_CLUSTERS,        FS_FREE_SIZE / (FS_CLUSTER_SIZE + 2)  ; +2 for doubly linked FAT
.equ    FAT_BYTE_SIZE,          FS_MAX_CLUSTERS * 2

; error handling for FS_MAX_CLUSTERS greater than 250
.iflt 250 - FS_MAX_CLUSTERS         ; test if 250 - FS_MAX_CLUSTERS is less than 0
    .err                            ; address overflow!
.endif


.equ    FATFREECTR,             EEPROM_RESERVED_SIZE         ; 1 byte free cluster counter as FS_MAX_BLOCKS is restricted to 250
.equ    FAT_START,              FATFREECTR + 1
.equ    FAT_END,                FAT_START + FAT_BYTE_SIZE



; -------------------------------------------------

; gpio config
.equ    BUZZER_PIN,         1
.equ    GPIO_BTN_0,         4
; ADC voltage divider buttons
.equ    ADC_CHAN_0,         0                               ; channel 0 is mapped to ADC hardware channel 0
.equ    ADC_CHAN_1,         3                               ; channel 1 is mapped to ADC hardware channel 3

.equ    ADC_CHAN_0_PIN,     5
.equ    ADC_CHAN_1_PIN,     3

; -------------------------------------------------

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
;
; ADC button        | Resistance (R2) | Voltage | ADC threshold (8 MSB precision)
; ------------------|-----------------|---------|----------------------
; ADC_VD_CH0_BTN_0  | 51 K            | 1.222 v | 0x70    | 0b01110000
; ADC_VD_CH0_BTN_1  | 68 K            | 1.395 v | 0x80    | 0b10000000
; ADC_VD_CH0_BTN_2  | 100 K           | 1.613 v | 0x94    | 0b10010100
; ADC_VD_CH0_BTN_3  | 300 K           | 2.074 v | 0xbf    | 0b10111111
; ADC_VD_CH0_BTN_4  | 1 M             | 2.305 v | 0xd4    | 0b11010100


.equ    ADC_VD_CH0_BTN_0,       0                       ; bit corresponding to button 0
.equ    ADC_VD_CH0_BTN_1,       1                       ; bit corresponding to button 1
.equ    ADC_VD_CH0_BTN_2,       2                       ; bit corresponding to button 2
.equ    ADC_VD_CH0_BTN_3,       3                       ; bit corresponding to button 3
.equ    ADC_VD_CH0_BTN_4,       4                       ; bit corresponding to button 4

.equ    ADC_VD_CH0_BTN_0_TRESH, 0x70 + 16               ; ADC threshold for button 0
.equ    ADC_VD_CH0_BTN_1_TRESH, 0x80 + 16               ; ADC threshold for button 1
.equ    ADC_VD_CH0_BTN_2_TRESH, 0x94 + 16 + 8           ; ADC threshold for button 2 - slightly tuned up
.equ    ADC_VD_CH0_BTN_3_TRESH, 0xbf + 16               ; ADC threshold for button 3
.equ    ADC_VD_CH0_BTN_4_TRESH, 0xd4 + 16               ; ADC threshold for button 4

; -------------------------------------------------
; similarly, chanel 2 (R1 = 37 kilo ohm, VREF = VIN = vcc = 2.95 v)
; ADC button        | Resistance (R2) | Voltage | ADC threshold (8 MSB precision)
; ------------------|-----------------|---------|----------------------
; ADC_VD_CH1_BTN_0  | 5.1 K           | 0.357 v | 0x1f    | 0b00011111
; ADC_VD_CH1_BTN_1  | 20 K            | 1.035 v | 0x59    | 0b01011001
; ADC_VD_CH1_BTN_2  | 51 K            | 1.710 v | 0x94    | 0b10100101

.equ    ADC_VD_CH1_BTN_0,       5                       ; bit corresponding to channel 1 button 0
.equ    ADC_VD_CH1_BTN_1,       6                       ; bit corresponding to channel 1 button 1
.equ    ADC_VD_CH1_BTN_2,       7                       ; bit corresponding to channel 1 button 2

.equ    ADC_VD_CH1_BTN_0_TRESH, 0x1f + 20               ; ADC threshold for channel 1 button 0
.equ    ADC_VD_CH1_BTN_1_TRESH, 0x59 + 20               ; ADC threshold for channel 1 button 1
.equ    ADC_VD_CH1_BTN_2_TRESH, 0x94 + 20               ; ADC threshold for channel 1 button 2


; -------------------------------------------------
; Reading button presses (Software stabilization)
;     - ADC clock speed is clk / 128. for clk = 16 MHz, ADC clock speed will be 125 kHz
;     - ADC generally takes about 13 - 15 ADC clocks to perform a conversion.
;     - Let's approx to 14 which gives us a conversion frequency of ~9 kHz (i.e. once every ~110 micro seconds)
;     - We're using a 680 pF capacitor against 50 k ohm internal pull-up (RESET pin) for smoothing. So, time to charge up to 63% is (50 * 10**3 * 681 * 10**-12) = 34 micro seconds (TAO).
;         We might read a wrong value during this charge / discharge time. We can assume that the capacitor will be reasonably full at 5 * TAO
;     - Given the ADC conversion period (110 micro seconds), we should make sure multiple readings are within threshold to confirm a button press
;     - To be absolutely safe, we can take a bunch of readings waiting a few ms between them; report a press only if all the readings pass the same threshold

.equ    ADC_BTN_NUM_RE_READS,      15
.equ    ADC_BTN_RE_READ_INTERVAL,  3           ; milli seconds
; -------------------------------------------------
.equ    PC_BTN_WAIT_INTERVAL,      76          ; 20 us -> see timer_delay_clock_cycles
; -------------------------------------------------


.equ    TERMINAL_PROMPT_CHAR,      '>'
