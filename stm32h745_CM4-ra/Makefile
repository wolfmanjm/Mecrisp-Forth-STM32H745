
ARMGNU?=arm-none-eabi

COPS = -Wall  -Og -nostdlib -nostartfiles -ffreestanding -save-temps
AOPS = --warn --fatal-warnings

TARGET = stm32h745_CM4
PROJECT = mecrisp-stellaris-$(TARGET)

all : $(PROJECT).bin $(PROJECT).hex

$(PROJECT).o : flash.s interrupts.s $(PROJECT).s terminal.s vectors.s swdcomm.s
	$(ARMGNU)-as -g $(PROJECT).s -o $(PROJECT).o

# offset 0x08100000 to enable flash with st-link utility
$(PROJECT).hex : $(PROJECT).bin
	$(ARMGNU)-objcopy -I binary -O ihex --change-addresses 0x081C0000 $(PROJECT).bin $(PROJECT).hex

$(PROJECT).bin : memmap $(PROJECT).o
	$(ARMGNU)-ld -g -o $(PROJECT).elf -print-memory-usage -T memmap $(PROJECT).o
	$(ARMGNU)-objdump -D $(PROJECT).elf > $(PROJECT).list
	$(ARMGNU)-objcopy $(PROJECT).elf $(PROJECT).bin -O binary
	$(ARMGNU)-objdump --source --all-headers --demangle --line-numbers --wide $(PROJECT).elf > $(PROJECT).lst

clean:
	rm -f *.bin
	rm -f *.o
	rm -f *.elf
	rm -f *.list
	rm -f *.lst
	rm -f *.hex

