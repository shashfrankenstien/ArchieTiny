# Archie Tiny OS (ATtiny85)

- https://www.youtube.com/playlist?list=PLuCmHWky5GN4iyRNNchJ4GMcVCSOgdOvc
- http://www.avr-asm-tutorial.net/
- https://blog.oddbit.com/post/2019-01-22-debugging-attiny-code-pt-1/

# Deps

```
sudo apt-get install avr-libc binutils-avr gcc-avr avrdude
sudo apt install simavr
```


# NOTES

- Timer 0 in CTC mode - TCNT0,TCCR0A,TCCR0B,OCR0A
- Timer compare A interrupt at addr 0x000A; enabled in TIMSK
- Ugh, need to add `-nostartfiles` to avr-gcc so it doesn't include weird extra code that kills interrupts.
    - This also eliminates need to create and expose a global `main` routine


# Simulator

- use simavr + gdb combo - see Makefile sim: and gdb: labels
- simavr clock seems difficult to manage (need to verify) - https://github.com/buserror/simavr/issues/201
- see debug.gdb for hacky time estimation command


# Digispark fuses
- Low fuse: 0xe1  -- 16 MHz mode with no clock divide
- High fuse: 0x5d -- EEPROM not preserved, Watchdog timer always on
- Extended fuse:  -- Self-programming enabled

# Raw attiny85 using ESP8266

https://github.com/vince-br-549/ESP8266-as-ISP

Also just grab the

Function| ESP8266 | ATtiny85
---|---|---
SCK | D5 | pin 7
MISO | D6 | pin 6
MOSI | D7 | pin 5
RESET | 10 | pin 1
GND | GND | pin 4
VCC | 3.3v | pin 8



# Some STM8S stuff

- https://lujji.github.io/blog/
