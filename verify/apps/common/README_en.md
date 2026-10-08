# Bare-Metal C Runtime Environment for verify/common

`verify/common` provides the shared bare-metal C execution environment for
LoongArch verification applications, including the hello, coremark programs 
under `verify/apps`. Application Makefiles only need to select
`LA_PROFILE`; the common layer centrally manages the common library, startup
files, linker script, and toolchain prefix.

## Directory Layout

- `crt/start.S`: Reset entry. Initializes general-purpose registers, DMW, and
  CSRs; selects a private stack for each hart; calls `la_runtime_init(hart_id)`;
  then enters `main()`.
- `include/`: New common interfaces that consistently use the `la_*` prefix,
  such as `la_io.h`, `la_timer.h`, `la_runtime.h`, and `la_heap.h`.
- `lib/`: Runtime implementation, including console output, timer,
  bss/init-array initialization, heap, system-call stubs, and assertions.
- `clib/`: Lightweight C library and compatibility headers for legacy
  applications, including `string.*`, `config.h`, `timer.h`, and
  `uart.*`.
- `newlib_wrap/`: Lightweight implementations of `printf`, `snprintf`,
  and `vasprintf`.
- `mk/toolchain.mk`: Unified 32-bit/64-bit toolchain selection.
- `mk/common.mk`: Unified build rules for the common library and `start.o`.
- `linker.script`: Bare-metal link layout providing symbols for bss, stack,
  heap, init/fini arrays, and so on.

## Integrating an Application

Application Makefiles are recommended to integrate the common environment in
the following order:

```makefile
ROOT := ../../..
LA_PROFILE ?= la32r
include $(ROOT)/verify/apps/common/mk/toolchain.mk

COMMON := $(ROOT)/verify/apps/common
CCFLAGS ?= $(COMMON_CFLAGS) -O2 -fno-builtin

BUILD_DIR ?= build/$(LA_PROFILE)
OBJ_DIR := $(BUILD_DIR)/obj
LA_LIB := $(BUILD_DIR)/libla.a
START_OBJ := $(OBJ_DIR)/start.o

include $(COMMON)/mk/common.mk
INCLUDES := $(COMMON_INCLUDES)
```

Select the target with `LA_PROFILE` at build time:

```sh
make -C verify/apps/coremark LA_PROFILE=la32r
make -C verify/apps/coremark LA_PROFILE=la64
```

## Runtime Features

- C entry: `_start -> la_runtime_init(hart_id) -> main -> exit`.
- Multicore boot: up to four harts each have an 8 KiB private stack; hart0
  exclusively initializes `.bss` and init/fini arrays, while secondary harts
  wait for shared initialization to complete through a ready barrier with
  `dbar`.
- Memory initialization: during boot, hart0 clears `.bss` and executes
  `.preinit_array/.init_array`; it executes `.fini_array` on exit.
- Heap: provides a simple bump allocator supporting
  `malloc/calloc/realloc/free/strdup/sbrk`.
- I/O: `printf` ultimately writes through `fputc()` to the simulation
  console MMIO address.
- Timer: LA64 uses `rdtime.d`; LA32R reads the hardware counter with
  `rdtimel.w`.
- System-call stubs: provides common bare-metal compatibility interfaces such
  as `_write/_read/_sbrk/_exit/_fstat/_isatty/gettimeofday`.
- Assertions: provides `LA_ASSERT()`, `__assert_fail()`, and
  `__assert_func()`.

## Naming Convention

Common interfaces consistently use the `la_*` prefix. Legacy external project
names and interfaces have been removed from the common source tree to avoid
ownership and symbol conflicts with other projects or third-party SDKs.

## Notes

- The current heap is located after `.stack` and before `.dymmy_exit`. Its
  space is controlled by `_heap_start` and `_heap_end` in
  `linker.script`.
- `free()` is currently a no-op. This is appropriate for verification
  programs and short-lived bare-metal applications; long-running applications
  should extend the allocator.
- `linker.script` uses PHDRS to map code and read-only segments as `R E`
  LOAD segments, and data, bss, stack, and simulation-exit segments as `RW`
  LOAD segments.
