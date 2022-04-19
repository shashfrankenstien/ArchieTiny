# Archie Tiny OS (ATtiny85)

- https://www.youtube.com/playlist?list=PLuCmHWky5GN4iyRNNchJ4GMcVCSOgdOvc
- http://www.avr-asm-tutorial.net/
- https://blog.oddbit.com/post/2019-01-22-debugging-attiny-code-pt-1/
- http://www.rjhcoding.com/avr-asm-macros.php
- https://www.youtube.com/watch?v=tFSTG7XEboI&list=PLuCmHWky5GN4iyRNNchJ4GMcVCSOgdOvc&index=5
- https://ftp.gnu.org/pub/old-gnu/Manuals/gas-2.9.1/html_chapter/as_7.html


## Debugging
- https://github.com/vince-br-549/ESP8266-as-ISP
- https://randomnerdtutorials.com/arduino-poor-mans-oscilloscope/
- https://sites.google.com/site/wayneholder/debugwire2
- https://sites.google.com/site/wayneholder/attiny-fuse-reset
- https://sites.google.com/site/wayneholder/attiny-fuse-reset-with-12-volt-charge-pump

## Deps

```
sudo apt-get install avr-libc binutils-avr gcc-avr avrdude
sudo apt install simavr
```


## Simulator

- use simavr + gdb combo - see Makefile sim: and gdb: labels
- simavr clock seems difficult to manage (need to verify) - https://github.com/buserror/simavr/issues/201
- see debug.gdb for hacky time estimation command

to compile simavr, we need glut
```
sudo apt install freeglut3-dev
```

# Digispark
### fuses
- Low fuse: 0xe1  -- 16 MHz mode with no clock divide
- High fuse: 0x5d -- EEPROM not preserved, Watchdog timer always on
- Extended fuse: 0xfe -- Self-programming enabled



# Raw attiny85 using ATTinyDebugTools

https://github.com/shashfrankenstien/ATTinyDebugTools

Function| ATTinyDebugTools | ATtiny85
---|---|---
SCK | D13 | pin 7
MISO | D12 | pin 6
MOSI | D11 | pin 5
VCC | D10 | pin 8
RESET | D6 | pin 1
GND | GND | pin 4

### default fuses
- Low fuse: 0x62  -- 8 MHz mode with clock divide by 8 (1 MHz)
- High fuse: 0xdf -- SPI enabled
- Extended fuse: 0xff  -- Self-programming disabled

### change to 16 MHz clock
- Low fuse: 0xe1  -- 16 MHz mode with no clock divide



-----

# ArchieTiny implementation NOTES

- Timer 0 in CTC mode - TCNT0,TCCR0A,TCCR0B,OCR0A
- Timer compare A interrupt at addr 0x000A; enabled in TIMSK
- Ugh, need to add `-nostartfiles` to avr-gcc so it doesn't include weird extra code that kills interrupts.
    - This also eliminates need to create and expose a global `main` routine

## Time and Delays (time.asm)
- Features
    - 24 bit software time counter - this requires that `timer_tick_isr` is attached to an interrupt that triggers every 1 millisecond
    - also includes a sort of accurate clock cycle counter delay. (see `timer_delay_clock_cycles` subroutine)
- Ticks are stored in addressed by TIME_SOFT_COUNTER config variable
    - HIGH_BYTE:MIDDLE_BYTE:LOW_BYTE
    - TIME_SOFT_COUNTER+2:TIME_SOFT_COUNTER+1:TIME_SOFT_COUNTER

## Resource Status Registers
- Each of the below resources are allocated 1 register of size 1 byte to store custom status flags
- Each of these status registers are described within their corresponding modules

Resource | Register config name | Module
---------|----------------------|-------------
I2C      | SREG_I2C             | usi_i2c.asm
Oled     | SREG_OLED            | sh1106.asm
GPIO     | SREG_GPIO_PC         | gpio.asm


## Task Manager (tasks.asm)
Tasks Table is set up starting at RAM address TASK_TABLE_START (Should be greater than 0x60 = 32 general registers + 64 I/O registers).


### Task table
- First byte will be the task counter (TASKCTS)
- Second byte will be current task index (TASKPTR)
- Next addresses will contain word size values of task stack pointers
    - Note: Because of how the stack pointer works, task address should be divided by 2. cpu will then multiply it by 2 before executing

### Task workflow
- init
    - set TASKCTS and TASKPTR to 0
- add new task
    - increment TASKPTR till we find an empty slot in TASK_SP_VECTOR
    - calculate stack pointer address and store in TASK_SP_VECTOR at TASKPTR index
    - jump to task's alotted stack
    - store return address, function pointer + manager pushed registers on the stack
    - if TASK_SP_VECTOR is full, set FULL flag in TASKCTS
- exec task
    - read TASKCTS counter, if eq 0 or 1, simply return because there is no task switching required
    - if RUNNING bit is set, there was previously a task that was running
    - push registers + SREG to stack, read TASKPTR, save stack pointer in TASK_SP_VECTOR at TASKPTR index
    - increment TASKPTR to go to next task
        - initially, TASKPTR will be 0
        - if TASKPTR overflows beyond TASK_MAX_TASKS, wrap around to 0
    - load stack pointer value from TASK_SP_VECTOR at TASKPTR index
    - set new stack pointer, pop all registers + SREG
    - reti


## I2C
- Built-in USI I2C
    - outputs USIDR MSB on SDA line on falling edge of SCL
    - slave devices read on rising edge of SCL
    - slave addresses seem to be shifted left
        - for example, in SH1106, documentation says addresses are 0111100 and 0111101, but in reality, device only reponds to 01111000 and 01111001
- SREG_I2C - i2c status register
    - register holds 8 i2c status flags
    - currently only 1 bit is assigned - I2C bus lock bit (I2C_BUS_LOCK)
- I2C_BUS_LOCK (bit 0)
    - a lock can be acquired by setting I2C_BUS_LOCK bit in SREG_I2C to 1, and released by clearing it to 0
    - tasks using i2c should use i2c_lock_acquire and i2c_lock_release. these routines facilitate wait-aquire-release workflow


## OLED display (using I2C)
- SH1106 Command Table is on page 30 of the datasheet
- documentation and resources recommend sleeping for 100 ms before displaying anything on the screen
- fonts - https://github.com/Tecate/bitmap-fonts - see vendor/bdf_fonts for more
    - bitocra7
    - spleen
    - unscii-fantasy
- when including strings in program memory, we need to mind byte alignment.
    use `.balign 2` after each string definition
- SREG_OLED is used to track color inversion (highlight) and page scroll position


## Controls
### Button press event manager (PCINT)
- digital pin change interrupts (active low) - interrupt triggers for both falling and rising edges
    - on falling edge (button press), both GPIO_BTN_x_PRS and GPIO_BTN_x_HLD bits are set in SREG_GPIO_PC
    - Any program handling button press must clear GPIO_BTN_x_PRS bit after handing the press
    - on rising edge interrupt (button release), GPIO_BTN_x_HLD bits are automatically cleared

### Button press (voltage divided ADC)
- ADC ISR writes 8-bit precision byte from ADC_VD_BTNS_CHAN to ADC_VD_BTNS_VAL register. We can use this byte to identify button press and release
- Since this method can technically support quite a few buttons, we use 2 bytes to report on press and release state (this can thus support upto 8 buttons)
- We need to check expected voltage levels in ascending order
    - only 1 button can be pressed at a time.
    - check lowest voltage threshold. If ADC reading is lower, set ADC_VD_BTN_x bit in r16 indicating press
    - continue checking as long as no press is identified

- Reading button presses (Software stabilization)
    - ADC clock speed is clk / 128. for clk = 16 MHz, ADC clock speed will be 125 kHz
    - ADC generally takes about 13 - 15 ADC clocks to perform a conversion.
    - Let's approx to 14 which gives us a conversion frequency of ~9 kHz (i.e. once every ~110 micro seconds)
    - We're using a 2200 pF capacitor against 60 k ohm internal pull-up (RESET pin) for smoothing. So, time to charge up to 63% is (60 * 10^3 * 2200 * 10^-12) = 132 micro seconds (TAO).
        We might read a wrong value during this charge / discharge time. We can assume that the capacitor will be reasonably full at 3 * TAO
    - Given the ADC conversion period (110 micro seconds), we should require that atleast 4 readings are within threshold to confirm a button press
    - To be absolutely safe, we can take 3 readings waiting 1 ms between them (Almost 30 ISR readings over all) and report a press only if all 3 readings pass the threshold

- ADC voltage divider value calculation (RESET pin)
    - tested on RESET pin (internal pull up resistance (R1))
    - because we're using the reset pin, input voltage cannot be below ~1.3 v (documentation says 0.9 v :/)

    - equations (only care about 8 MSB precision)
        - VOUT = lambda VIN, R1, R2: VIN * R2/(R1+R2)
        - ADC_VAL = lambda VREF, VOUT: int((VOUT * 1024) / VREF) >> 2

    - approx measured / fudged values that worked out in tests
        - VREF = Vcc = 2.8 v
        - VIN = Vpin = 2.6 v
        - R2 = RESET pin pull-up = 50 kilo ohm aprox (??)

ADC button    | Resistance (R2) | Voltage | ADC threshold (8 MSB precision)
--------------|-----------------|---------|--------------
ADC_VD_BTN_0  | 51 K            | 1.313 v | 0b01111000
ADC_VD_BTN_1  | 100 K           | 1.733 v | 0b10011110
ADC_VD_BTN_2  | 220 K           | 2.118 v | 0b11000001
ADC_VD_BTN_3  | 300 K           | 2.229 v | 0b11001011
ADC_VD_BTN_4  | 1 M             | 2.476 v | 0b11100010




## EEPROM FAT-8 File System (TODO)
- https://www.youtube.com/watch?v=HjVktRd35G8


-----

[docs/Atmel-AT1886-Mix-C-and-Asm.pdf](docs/Atmel-AT1886-Mix-C-and-Asm.pdf)

Table 5-1. Summary of the register interfaces between C and assembly.
Register | Description | Assembly code called from C | Assembly code that calls C code
---------|-------------|-----------------------------|--------------------------------
r0 | Temporary | Save and restore if using | Save and restore if using
r1 | Always zero | Must clear before returning | Must clear before calling
r2-r17 | “call-saved” | Save and restore if using | Can freely use
r28    | “call-saved” | Save and restore if using | Can freely use
r29    | “call-saved” | Save and restore if using | Can freely use
r18-r27 | “call-used” | Can freely use | Save and restore if using
r30     | “call-used” | Can freely use | Save and restore if using
r31     | “call-used” | Can freely use | Save and restore if using


-----

# Some STM8S stuff

- https://lujji.github.io/blog/


-----

# Some PIC stuff

- https://www.youtube.com/watch?v=DBftApUQ8QI
