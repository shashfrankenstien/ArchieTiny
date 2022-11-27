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
.equ    I2C_BUS_RLOCK,            TIME_SOFT_COUNTER + 3       ; set this to TIME_SOFT_COUNTER + 3 since the time counter is 24 bits (3 bytes)
.equ    SREG_OLED,                I2C_BUS_RLOCK + 1
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
.iflt 256 - MALLOC_FREE_RAM         ; if more than 256 bytes of memory is free, default to 256 so that we can use 8 bit pointer addressing
    .equ    MALLOC_FREE_RAM,   256  ; address overflow!
.endif


.equ    MALLOC_BLOCK_SIZE,     8
.equ    MALLOC_MAX_BLOCKS,     (MALLOC_FREE_RAM / (MALLOC_BLOCK_SIZE + 1))  ; look for space for 1 additional byte for the malloc table
.equ    MALLOC_TABLE_SIZE,     MALLOC_MAX_BLOCKS


.equ    MALLOCFREECTR,                   FREE_RAM_START       ; 1 byte

.equ    MALLOC_RAM_START,                MALLOCFREECTR
.equ    MALLOC_TABLE_START,              MALLOCFREECTR + 1
.equ    MALLOC_TABLE_END,                MALLOC_TABLE_START + MALLOC_TABLE_SIZE
.equ    MALLOC_RAM_END,                  MALLOC_TABLE_END + (MALLOC_BLOCK_SIZE * MALLOC_MAX_BLOCKS)

; -------------------------------------------------



.equ    EEPROM_SIZE,            512                          ; bytes
.equ    EEPROM_RESERVED_SIZE,   5


.equ    FS_FREE_SIZE,           EEPROM_SIZE - EEPROM_RESERVED_SIZE
.equ    FS_CLUSTER_SIZE,        20
.equ    FS_MAX_CLUSTERS,        FS_FREE_SIZE / (FS_CLUSTER_SIZE + 2)  ; +2 for doubly linked FAT
.equ    FAT_BYTE_SIZE,          FS_MAX_CLUSTERS * 2


.equ    FATFREECTR,             EEPROM_RESERVED_SIZE         ; 1 byte free cluster counter as FS_MAX_BLOCKS is restricted to 250
.equ    FAT_START,              FATFREECTR + 1
.equ    FAT_END,                FAT_START + FAT_BYTE_SIZE



; -------------------------------------------------

; gpio config
.equ    BUZZER_PIN,         1                               ; physical pin 6 - this can't change if we use PWM
.equ    GPIO_BTN_0,         4                               ; physical pin 3
; ADC voltage divider buttons
.equ    ADC_CHAN_0,         3                               ; channel 0 is mapped to ADC hardware channel 3 - physical pin 2
.equ    ADC_CHAN_1,         0                               ; channel 1 is mapped to ADC hardware channel 0 - physical pin 1 (RESET pin)

.equ    ADC_CHAN_0_PIN,     5
.equ    ADC_CHAN_1_PIN,     3

; -------------------------------------------------

; ADC voltage divider value calculation (internal pull up resistance R1)
;     - when using the reset pin, input voltage cannot be below ~1.3 v (documentation says 0.9 v :/)
;
;     - equations (only care about 8 MSB precision)
;         - VOUT = lambda VIN, R1, R2: VIN * R2/(R1+R2)
;         - ADC_VAL = lambda VREF, VOUT: int((VOUT * 1024) / VREF) >> 2
;
;     - below are approx measured / fudged values that worked out in tests
;     - voltages are usually below these values. just to be sure, we set the
;           threshold to be a few counts above these values (see config.inc)
;
;     - channel 0: PIN 2
;         - VREF = Vcc = 2.85 v
;         - VIN = Vpin = 2.8 v
;         - R1 = 35 kilo ohm aprox (guess??)
;
; ADC button        | Resistance (R2) | Voltage | ADC threshold (8 MSB precision)
; ------------------|-----------------|---------|----------------------
; ADC_VD_CH0_BTN_0  | 20 K            | 1.018 v | 0x5b
; ADC_VD_CH0_BTN_1  | 51 K            | 1.660 v | 0x95
; ADC_VD_CH0_BTN_2  | 68 K            | 1.849 v | 0xa6
; ADC_VD_CH0_BTN_3  | 100 K           | 2.074 v | 0xba
; ADC_VD_CH0_BTN_4  | 300 K           | 2.507 v | 0xe1

.equ    ADC_VD_CH0_BTN_0,       0                       ; bit corresponding to button 0
.equ    ADC_VD_CH0_BTN_1,       1                       ; bit corresponding to button 1
.equ    ADC_VD_CH0_BTN_2,       2                       ; bit corresponding to button 2
.equ    ADC_VD_CH0_BTN_3,       3                       ; bit corresponding to button 3
.equ    ADC_VD_CH0_BTN_4,       4                       ; bit corresponding to button 4

.equ    ADC_VD_CH0_BTN_0_TRESH, 0x5b + 10               ; ADC threshold for button 0
.equ    ADC_VD_CH0_BTN_1_TRESH, 0x95 + 10               ; ADC threshold for button 1
.equ    ADC_VD_CH0_BTN_2_TRESH, 0xa6 + 10               ; ADC threshold for button 2
.equ    ADC_VD_CH0_BTN_3_TRESH, 0xba + 10               ; ADC threshold for button 3
.equ    ADC_VD_CH0_BTN_4_TRESH, 0xe1 + 10 + 4           ; ADC threshold for button 4 - slightly tuned up

; -------------------------------------------------
; similarly, chanel 1 - PIN 1 (reset pin)
;         - VREF = Vcc = 2.8 v
;         - VIN = Vpin = 2.45 v
;         - R1 = RESET pin pull-up = 50 kilo ohm aprox (guess??)
;
;when using the reset pin, input voltage cannot be below ~1.3 v (documentation says 0.9 v :/).
;       to remedy this, reset pin resistors are all connected in series (each are 68 K)
;
; ADC button        | Resistance (R2) | Voltage | ADC threshold (8 MSB precision)
; ------------------|-----------------|---------|----------------------
; ADC_VD_CH1_BTN_0  | 68 K            | 1.412 v | 0x81
; ADC_VD_CH1_BTN_1  | 136 K           | 1.791 v | 0xa3
; ADC_VD_CH1_BTN_2  | 204 K           | 1.968 v | 0xb3

.equ    ADC_VD_CH1_BTN_0,       5                       ; bit corresponding to channel 1 button 0
.equ    ADC_VD_CH1_BTN_1,       6                       ; bit corresponding to channel 1 button 1
.equ    ADC_VD_CH1_BTN_2,       7                       ; bit corresponding to channel 1 button 2

.equ    ADC_VD_CH1_BTN_0_TRESH, 0x81 + 10               ; ADC threshold for channel 1 button 0
.equ    ADC_VD_CH1_BTN_1_TRESH, 0xa3 + 10               ; ADC threshold for channel 1 button 1
.equ    ADC_VD_CH1_BTN_2_TRESH, 0xb3 + 10 + 6           ; ADC threshold for channel 1 button 2 - slightly tuned up


; -------------------------------------------------
; Reading button presses (Software stabilization)
;     - ADC clock speed is clk / 128. for clk = 16 MHz, ADC clock speed will be 125 kHz
;     - ADC generally takes about 13 - 15 ADC clocks to perform a conversion.
;     - Let's approx to 14 which gives us a conversion frequency of ~9 kHz (i.e. once every ~110 micro seconds)
;     - We're using a 680 pF capacitor against 50 k ohm internal pull-up (RESET pin) for smoothing. So, time to charge up to 63% is (50 * 10**3 * 681 * 10**-12) = 34 micro seconds (TAO).
;         We might read a wrong value during this charge / discharge time. We can assume that the capacitor will be reasonably full at 5 * TAO
;     - Given the ADC conversion period (110 micro seconds), we should make sure multiple readings are within threshold to confirm a button press
;     - To be absolutely safe, we can take a bunch of readings waiting a few ms between them; report a press only if all the readings pass the same threshold

.equ    ADC_BTN_NUM_RE_READS,      18
.equ    ADC_BTN_RE_READ_INTERVAL,  3           ; milli seconds
; -------------------------------------------------
.equ    PC_BTN_WAIT_INTERVAL,      100         ; 20 to 30 us -> see timer_delay_clock_cycles
; -------------------------------------------------


.equ    TERMINAL_PROMPT_CHAR,      '>'







; -------------------------------------------------
; limit some variables
; task manager ------------------------------------

; error handling for TASK_MAX_TASKS greater than 16 - because TASKCTS has only a 4 bit task counter (and we don't have enough internal RAM of course)
.iflt 16 - TASK_MAX_TASKS           ; test if 16 - TASK_MAX_TASKS is less than 0
    .err                            ; max tasks overflow
.endif


; malloc (heap memory) ----------------------------

; error handling for 0 MALLOC_MAX_BLOCKS
.ifle MALLOC_MAX_BLOCKS
    .err                            ; no malloc-able blocks. check task manager memory allocation
.endif

; error handling for MALLOC_MAX_BLOCKS greater than 250 (never gonna happen since MALLOC_FREE_RAM is restricted to 256, but whatever)
.iflt 250 - MALLOC_MAX_BLOCKS       ; test if 250 - MALLOC_MAX_BLOCKS is less than 0
    .err                            ; address overflow!
.endif

; error handling for overflow
.ifle ((RAMEND - 8) - MALLOC_RAM_END)
    .err                            ; memory overflow!
.endif


; fs limit ----------------------------------------

; error handling for FAT_BYTE_SIZE greater than 250
.iflt 250 - FAT_BYTE_SIZE           ; test if 250 - FAT_BYTE_SIZE is less than 0
    .err                            ; address overflow!
.endif
