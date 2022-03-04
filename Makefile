MCU=attiny85
MICRONUCLEUS=vendor/micronucleus/commandline/micronucleus
BUILD_PREFIX=build/main

SRC=main.asm

all: $(BUILD_PREFIX).hex

build:
	mkdir -p build
# avr-gcc -x assembler-with-cpp -mmcu=$(MCU) -Os main.asm -o build/main.o
# avr-objcopy -O ihex --remove-section=.eeprom build/main.o build/main.hex

$(MICRONUCLEUS):
	cd vendor/micronucleus/commandline && make


$(BUILD_PREFIX).o: build
	avr-as -Wall -mmcu=$(MCU) -a=$(BUILD_PREFIX).list -o $@ $(SRC)

$(KERNEL_PREFIX).o: build
	avr-gcc -Wall -mmcu=$(MCU) -o $@ -c kernel.c


$(BUILD_PREFIX).elf: $(BUILD_PREFIX).o
	avr-gcc -g -O1 -mmcu=$(MCU) -o $@ $< -nostartfiles -DF_CPU=16500000L


$(BUILD_PREFIX).hex: $(BUILD_PREFIX).elf
	avr-objcopy -j .text -j .data -O ihex $< $@
	avr-objdump -h -S $< > $(BUILD_PREFIX).dis


flash-avr: $(BUILD_PREFIX).hex
# avrdude -P /dev/ttyUSB0 -c stk500v1 -b 19200 -p $(MCU)
	avrdude -v -v -v -v -p$(MCU) -cstk500v1 -P/dev/ttyUSB0 -b19200 -e -Uefuse:w:0xff:m -Uhfuse:w:0xdf:m -Ulfuse:w:0x62:m
	avrdude -P /dev/ttyUSB0 -c stk500v1 -b 19200 -p $(MCU) -D -U flash:w:$<:i



flash-digispark: $(BUILD_PREFIX).hex
	/home/shashankgopikrishna/.arduino15/packages/digistump/tools/micronucleus/2.0a4/launcher -cdigispark --timeout 60 -Uflash:w:$(BUILD_PREFIX).hex:i

flash-micronucleus: $(MICRONUCLEUS)
	$(MICRONUCLEUS) --timeout 60 $(BUILD_PREFIX).hex --run


clean:
	rm -rf build

# simulator and gdb setup
sim:
	simavr -m attiny85 -f 16500000 $(BUILD_PREFIX).elf  -g
gdb:
	avr-gdb --command=debug.gdb
