CROSS_COMPILE ?= loongarch32s-unknown-linux-gnusf-

CC = $(CROSS_COMPILE)gcc
LD = $(CROSS_COMPILE)ld
OBJDUMP = $(CROSS_COMPILE)objdump
OBJCOPY = $(CROSS_COMPILE)objcopy
READELF = $(CROSS_COMPILE)readelf
SIZE = $(CROSS_COMPILE)size

INCLUDES := -I.

CCFLAGS := -march=la32v1.0 -mabi=ilp32s -static -G0 -pipe -g -O2
CCFLAGS += -ffreestanding -fno-pic -fno-pie -fno-stack-protector
CCFLAGS += -fno-asynchronous-unwind-tables -fno-unwind-tables
CCFLAGS += -DBL_PAYLOAD=\"vmlinux.bin\"

LOADER_BOOTARGS ?=
BOOTARGS_HEADER := bootargs.h
LOADER_STATUS_ADDR ?= 0x1c100000
LOADER_STACK_ADDR ?= 0x12000000
LOADER_CONFIG_HEADER := loader_config.h

LDFLAGS := -Tlink.lds -Map=link.map -static

LDFLAGS += --defsym=MEM_START=0x1c000000
LDFLAGS += --defsym=LOADER_LIMIT=$(LOADER_STATUS_ADDR)

# --gc-sections, we ignored all "Unnecessary* sections and symbols
# -u instead of all symbol are checked out
# LDFLAGS += --gc-sections -u _start #

# Use the kernel whose source DT already describes the FPGA memory, UART
# register spacing, and UART interrupt.  Do not patch its built-in DTB here.
KERNEL_DIR ?= linux-7.2.0-la132s
KERNEL_ELF := $(KERNEL_DIR)/vmlinux

##-----------------------------------------------------##
BIOS_NAME = loader#
##-----------------------------------------------------##


all: $(BIOS_NAME).bin vmlinux.bin

OBJ = start.o dbg_uart.o

$(BOOTARGS_HEADER): FORCE
	@tmp_file="$@.tmp"; \
	printf '%s\n' \
		'#ifndef OPENLA132S_LOADER_BOOTARGS_H' \
		'#define OPENLA132S_LOADER_BOOTARGS_H' \
		'#define LOADER_BOOTARGS "$(LOADER_BOOTARGS)"' \
		'#endif' > "$$tmp_file"; \
	if ! cmp -s "$$tmp_file" "$@"; then \
		mv "$$tmp_file" "$@"; \
	else \
		rm -f "$$tmp_file"; \
	fi

$(LOADER_CONFIG_HEADER): FORCE
	@tmp_file="$@.tmp"; \
	printf '%s\n' \
		'#ifndef OPENLA132S_LOADER_CONFIG_H' \
		'#define OPENLA132S_LOADER_CONFIG_H' \
		'#define LOADER_STATUS_ADDR $(LOADER_STATUS_ADDR)' \
		'#define LOADER_STACK_ADDR $(LOADER_STACK_ADDR)' \
		'#endif' > "$$tmp_file"; \
	if ! cmp -s "$$tmp_file" "$@"; then \
		mv "$$tmp_file" "$@"; \
	else \
		rm -f "$$tmp_file"; \
	fi

start.o: start.S entry.h $(BOOTARGS_HEADER) $(LOADER_CONFIG_HEADER)
	$(CC) $(CCFLAGS) $(INCLUDES) -D__ASSEMBLY__ -c $< -o $@

dbg_uart.o: dbg_uart.c
	$(CC) $(CCFLAGS) $(INCLUDES) -c $< -o $@

payload.o: payload_vmlinux
	$(CC) $(CCFLAGS) $(INCLUDES) -D__ASSEMBLY__ payload.S -c -o $@

check-kernel:
	@test -f "$(KERNEL_ELF)" || { \
		echo "missing LA32 kernel ELF: $(KERNEL_ELF)" >&2; \
		exit 1; \
	}; \
	elf_class="$$(LC_ALL=C $(READELF) -h "$(KERNEL_ELF)" | \
		awk '/Class:/ { print $$2; exit }')"; \
	if [ "$$elf_class" != ELF32 ]; then \
		echo "expected an ELF32 LA32 kernel, got $$elf_class" >&2; \
		exit 1; \
	fi

vmlinux.bin: check-kernel
	$(OBJCOPY) -O binary "$(KERNEL_ELF)" $@

entry.h: check-kernel
	@kernel_entry="$$(LC_ALL=C $(READELF) -h "$(KERNEL_ELF)" | \
		awk '/Entry point address:/ { print $$4; exit }')"; \
	if ! printf '%s\n' "$$kernel_entry" | grep -Eq '^0x[0-9a-fA-F]+$$'; then \
		echo "cannot read LA32 kernel entry from $(KERNEL_ELF)" >&2; \
		exit 1; \
	fi; \
	kernel_vseg=$$(((kernel_entry >> 29) & 0x7)); \
	if [ "$$kernel_vseg" -ne 4 ] && [ "$$kernel_vseg" -ne 5 ]; then \
		echo "LA32 kernel entry is not in a DMW segment: $$kernel_entry" >&2; \
		exit 1; \
	fi; \
	{ \
		echo '#ifndef OPENLA132S_LOADER_ENTRY_H'; \
		echo '#define OPENLA132S_LOADER_ENTRY_H'; \
		printf '#define KERNEL_ENTRY_DMW %s\n' "$$kernel_entry"; \
		echo '#endif'; \
	} > $@

payload_vmlinux: entry.h vmlinux.bin


$(BIOS_NAME).exe: $(OBJ)
	$(LD) $(LDFLAGS) -L. $(OBJ) -o $@
	$(OBJDUMP) -ald $@ > $@.S
	@echo "ELF SIZE DUMP:"
	@$(SIZE) $@ | tee $@.size


$(BIOS_NAME).bin: $(BIOS_NAME).exe
	$(OBJCOPY) -O binary $< $@
# 	dd if=vmlinux.bin of=$@ bs=1024 skip=1 seek=1

.PHONY: all check-kernel payload_vmlinux $(BIOS_NAME).exe FORCE

FORCE:

clean:
	rm -rf  $(BIOS_NAME).exe* link.map \
	*.hex* *.pat *.coe *.mif *.vlog *.o *.dtbo \
	$(BIOS_NAME).bin* payload_vmlinux $(BOOTARGS_HEADER) $(LOADER_CONFIG_HEADER) \
	vmlinux* la320.dtb tmp.txt entry.h
