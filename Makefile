MCU=attiny85
MICRONUCLEUS=vendor/micronucleus/commandline/micronucleus
SIMAVR=vendor/simavr/simavr/run_avr
PORT ?= /dev/ttyACM0
BUILD_PREFIX=build/kernel

SRC=src/kernel.asm \
	src/lib/timer.asm \
	src/lib/tasks.asm \
	src/lib/math.asm \
	src/drivers/usi_i2c.asm \
	src/drivers/gpio.asm \
	src/drivers/sh1106.asm \
	src/shell.asm \
	src/fonts/spleen.asm

all: $(BUILD_PREFIX).hex

build:
	mkdir -p build
# avr-gcc -x assembler-with-cpp -mmcu=$(MCU) -Os main.asm -o build/main.o
# avr-objcopy -O ihex --remove-section=.eeprom build/main.o build/main.hex

$(MICRONUCLEUS):
	cd vendor/micronucleus/commandline && make

$(SIMAVR):
	cd vendor/simavr/simavr && make


$(BUILD_PREFIX).o: build
	avr-as -Wall -mmcu=$(MCU) -a=$(BUILD_PREFIX).list -o $@ $(SRC) -I src

$(KERNEL_PREFIX).o: build
	avr-gcc -Wall -mmcu=$(MCU) -o $@ -c kernel.c


$(BUILD_PREFIX).elf: $(BUILD_PREFIX).o
	avr-gcc -g -O1 -mmcu=$(MCU) -o $@ $< -nostartfiles


$(BUILD_PREFIX).hex: $(BUILD_PREFIX).elf
	avr-objcopy -j .text -j .data -O ihex $< $@
	avr-objdump -h -S $< > $(BUILD_PREFIX).dis
	avr-size $<
	ls -all $@


flash-avr: $(BUILD_PREFIX).hex
	avrdude -v -p$(MCU) -cstk500v1 -P$(PORT) -b19200 -e -U efuse:w:0xff:m -U hfuse:w:0xdf:m -U lfuse:w:0xe1:m
	avrdude -P $(PORT) -c stk500v1 -b 19200 -p $(MCU) -D -U flash:w:$<:i


test-avr:
	avrdude -P $(PORT) -c stk500v1 -b 19200 -p $(MCU)

# debug-wire:
# 	./vendor/debugwire/connect.sh  $(PORT) 115200


flash-micronucleus: $(MICRONUCLEUS)
	$(MICRONUCLEUS) --timeout 60 $(BUILD_PREFIX).hex --run


clean:
	rm -rf build

# simulator and gdb setup
sim:
	$(SIMAVR) -m attiny85 -f 16000000 $(BUILD_PREFIX).elf  -g
gdb:
	avr-gdb --command=debug.gdb
sim-bg:
	make sim &
	make gdb
