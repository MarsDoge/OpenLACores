COMMON ?= $(ROOT)/verify/common
COMMON_INCLUDES ?= -I$(COMMON)/include -I$(COMMON)/clib

# printf/snprintf/asprintf layer used instead of linking a full libc.
COMMON_NEWLIB_SRCS ?= \
	$(COMMON)/newlib_wrap/printf.c \
	$(COMMON)/newlib_wrap/vasprintf.c

# Runtime services required by a freestanding C program.
COMMON_RUNTIME_SRCS ?= \
	$(COMMON)/lib/io.c \
	$(COMMON)/lib/time.c \
	$(COMMON)/lib/runtime.c \
	$(COMMON)/lib/heap.c \
	$(COMMON)/lib/syscalls.c \
	$(COMMON)/lib/assert.c

# Small C library and optional device helpers kept under clib for compatibility.
COMMON_CLIB_SRCS ?= \
	$(COMMON)/clib/string.c \
	$(COMMON)/clib/uart.c \
	$(COMMON)/clib/intc.c

COMMON_UTIL_SRCS ?= \
	$(COMMON)/utils/utils.c

COMMON_LIB_SRCS ?= \
	$(COMMON_NEWLIB_SRCS) \
	$(COMMON_RUNTIME_SRCS) \
	$(COMMON_CLIB_SRCS) \
	$(COMMON_UTIL_SRCS)

COMMON_LIB_OBJ := $(patsubst $(COMMON)/%.c,$(OBJ_DIR)/common/%.o,$(COMMON_LIB_SRCS))

# Mirror the source tree under OBJ_DIR so different apps/profiles never clash.
$(OBJ_DIR)/common/%.o: $(COMMON)/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CCFLAGS) $(COMMON_INCLUDES) -c $< -o $@

# Startup is kept outside libla.a so it is always linked first.
$(START_OBJ): $(COMMON)/crt/start.S
	@mkdir -p $(dir $@)
	$(CC) $(CCFLAGS) $(COMMON_INCLUDES) -c $< -o $@

$(LA_LIB): $(COMMON_LIB_OBJ)
	@mkdir -p $(dir $@)
	$(AR) rcs $@ $(COMMON_LIB_OBJ)
