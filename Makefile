MCU=attiny85
MICRONUCLEUS=vendor/micronucleus/commandline/micronucleus
BUILD_PREFIX=build/main


all: $(BUILD_PREFIX).hex

build:
	mkdir -p build
# avr-gcc -x assembler-with-cpp -mmcu=$(MCU) -Os main.asm -o build/main.o
# avr-objcopy -O ihex --remove-section=.eeprom build/main.o build/main.hex

$(MICRONUCLEUS):
	cd vendor/micronucleus/commandline && make


$(BUILD_PREFIX).o: build
	avr-as -Wall -mmcu=$(MCU) -a=$(BUILD_PREFIX).list -o $@ main.asm

$(KERNEL_PREFIX).o: build
	avr-gcc -Wall -mmcu=$(MCU) -o $@ -c kernel.c


$(BUILD_PREFIX).elf: $(BUILD_PREFIX).o
	avr-gcc -Os -mmcu=$(MCU) -o $@ $<


$(BUILD_PREFIX).hex: $(BUILD_PREFIX).elf
	avr-objcopy -O ihex $< $@


flash-avr: $(BUILD_PREFIX).hex
	avrdude -c arduino -b 57600 -p $(MCU) -D -U flash:w:$<:i


flash-digispark: $(BUILD_PREFIX).hex
	/home/shashankgopikrishna/.arduino15/packages/digistump/tools/micronucleus/2.0a4/launcher -cdigispark --timeout 60 -Uflash:w:$(BUILD_PREFIX).hex:i

flash-micronucleus: $(MICRONUCLEUS)
	$(MICRONUCLEUS) --timeout 60 $(BUILD_PREFIX).hex --run


clean:
	rm -rf build
