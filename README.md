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
    - 24 bit software time counter - this requires that `time_tick_isr` is attached to an interrupt that triggers every 1 millisecond
    - also includes a sort of accurate clock cycle counter delay. (see `time_delay_clock_cycles` subroutine)
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
GPIO     | SREG_GPIO_ADC (TODO) | gpio.asm


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
- fonts - https://github.com/Tecate/bitmap-fonts
    - bitocra7
    - lemon
    - spleen
- when including strings in program memory, we need to mind byte alignment.
    use `.balign 2` after each string definition

## Button press event manager (TODO)


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
