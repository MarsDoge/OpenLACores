ROOT := ../../..
LA_PROFILE ?= la32s
include $(ROOT)/verify/apps/common/mk/toolchain.mk

COMMON := $(ROOT)/verify/apps/common

CCFLAGS ?= -Wno-implicit-function-declaration $(COMMON_CFLAGS) -O0 -fno-builtin

TEST_CASE ?= hello_world
BUILD_DIR ?= build/$(LA_PROFILE)
OBJ_DIR := $(BUILD_DIR)/obj
LA_LIB := $(BUILD_DIR)/libla.a
START_OBJ := $(OBJ_DIR)/start.o
OUT_DIR ?= .
ifeq ($(OUT_DIR),.)
ELF := $(TEST_CASE).exe
BIN := $(TEST_CASE).bin
MAP_FILE ?= link.map
else
ELF := $(OUT_DIR)/$(TEST_CASE).exe
BIN := $(OUT_DIR)/$(TEST_CASE).bin
MAP_FILE ?= $(OUT_DIR)/link.map
endif
LDFLAGS += $(COMMON_LDFLAGS) -T$(COMMON)/linker.script -Map=$(MAP_FILE)

OBJCOPY_FLAGS := --set-section-flags .bss=alloc,load,contents \
                 --set-section-flags .stack=alloc,load,contents \
                 --set-section-flags .dymmy_exit=alloc,load,contents \
                 --set-section-flags .bss..page_aligned=alloc,load,contents

# Pull in the shared LoongArch bare-metal runtime and startup rules.
include $(COMMON)/mk/common.mk
INCLUDES := $(COMMON_INCLUDES)

.DEFAULT_GOAL := all

all: $(BIN)

HELLO_SRCS := src/hello_world.c
HELLO_OBJ := $(patsubst %.c,$(OBJ_DIR)/app/%.o,$(HELLO_SRCS))

$(OBJ_DIR)/app/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CCFLAGS) $(INCLUDES) -c $< -o $@

lib_obj: $(LA_LIB)

crt: $(START_OBJ)

$(ELF): $(LA_LIB) $(START_OBJ) $(HELLO_OBJ)
	@mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) -L$(dir $(LA_LIB)) $(START_OBJ) $(HELLO_OBJ) -o $@ --start-group -lla --end-group $(LIBGCC)
	$(OBJDUMP) -alD $@ > $@.S
	@echo "ELF SIZE DUMP:"
	@$(SIZE) $@ | tee $@.size

$(BIN): $(ELF)
	@mkdir -p $(dir $@)
	$(OBJCOPY) -O binary $< $@ $(OBJCOPY_FLAGS)
	$(OBJCOPY) -O binary $< $@.text -j .text* -j .rodata* -j .eh_frame*
	$(OBJCOPY) -O binary $< $@.data -j .data* -j .bss -j .COMMON -j .bss..page_aligned

clean:
	rm -rf build *.exe* link.map *.hex* *.pat *.bin* *.o src/*.o

.PHONY: all lib_obj crt clean
