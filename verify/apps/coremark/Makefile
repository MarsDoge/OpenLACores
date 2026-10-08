ROOT := ../../..
LA_PROFILE ?= la32s
NUM_CORES ?= 1
include $(ROOT)/verify/apps/common/mk/toolchain.mk

COMMON := $(ROOT)/verify/apps/common

CCFLAGS ?= $(COMMON_CFLAGS) -O2 -fno-builtin
CCFLAGS += -DCOREMARK_HART_COUNT=$(NUM_CORES)

TEST_CASE ?= coremark
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

COREMARK_SRCS := \
	src/core_list_join.c \
	src/core_util.c \
	src/core_matrix.c \
	src/core_portme.c \
	src/core_state.c \
	src/core_main.c
COREMARK_OBJ := $(patsubst %.c,$(OBJ_DIR)/app/%.o,$(COREMARK_SRCS))

$(OBJ_DIR)/app/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CCFLAGS) $(INCLUDES) -c $< -o $@

lib_obj: $(LA_LIB)

crt: $(START_OBJ)

$(ELF): $(LA_LIB) $(START_OBJ) $(COREMARK_OBJ)
	@mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) -L$(dir $(LA_LIB)) $(START_OBJ) $(COREMARK_OBJ) -o $@ --start-group -lla --end-group $(LIBGCC)
	$(OBJDUMP) -alD $@ > $@.S
	@echo "ELF SIZE DUMP:"
	@$(SIZE) $@ | tee $@.size

$(BIN): $(ELF)
	@mkdir -p $(dir $@)
	$(OBJCOPY) -O binary $< $@ $(OBJCOPY_FLAGS)
	$(OBJCOPY) -O binary $< $@.text -j .text* -j .rodata* -j .eh_frame*
	$(OBJCOPY) -O binary $< $@.data -j .data* -j .bss -j .COMMON -j .bss..page_aligned

clean:
	rm -rf build *.exe* link.map *.hex* *.pat *.bin* *.o coremark/*.o

.PHONY: all lib_obj crt clean
