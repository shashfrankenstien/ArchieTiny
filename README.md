# Archie Tiny OS (ATtiny85)

- https://www.youtube.com/playlist?list=PLuCmHWky5GN4iyRNNchJ4GMcVCSOgdOvc
- http://www.avr-asm-tutorial.net/
- https://blog.oddbit.com/post/2019-01-22-debugging-attiny-code-pt-1/
- http://www.rjhcoding.com/avr-asm-macros.php
- https://www.youtube.com/watch?v=tFSTG7XEboI&list=PLuCmHWky5GN4iyRNNchJ4GMcVCSOgdOvc&index=5

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



# Raw attiny85 using ESP8266 as ISP

https://github.com/vince-br-549/ESP8266-as-ISP

Use the [vendor/esp8266_isp.ino](vendor/esp8266_isp.ino) file to convert an ESP8266 into an ISP

Function| ESP8266 | ATtiny85
---|---|---
SCK | D5 | pin 7
MISO | D6 | pin 6
MOSI | D7 | pin 5
RESET | 10 | pin 1
GND | GND | pin 4
VCC | 3.3v | pin 8

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

## task manager (tasks.asm)
Tasks Table is set up starting at RAM address TASK_TABLE_START (Should be greater than 0x60 = 32 general registers + 64 I/O registers).

### Task table
- First byte will be the TASK_COUNTER
- Second byte will be current TASK_POINTER
- Next addresses will contain word size addresses to registered tasks
    - Note: Because of how the `Z` register works with `icall`, task address should be divided by 2. `icall` will then multiply it by 2 before executing

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
    - read TASKCTS counter, if eq 0, simply return because there are no registered tasks
    - if RUNNING bit is set, there was previously a task that was running
    - push registers + SREG to stack, read TASKPTR, save stack pointer in TASK_SP_VECTOR at TASKPTR index
    - increment TASKPTR to go to next task
        - initially, TASKPTR will be 0
        - if TASKPTR overflows beyond TASK_MAX_TASKS, wrap around to 0
    - load stack pointer value from TASK_SP_VECTOR at TASKPTR index
    - set new stack pointer, pop all registers + SREG
    - reti

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
