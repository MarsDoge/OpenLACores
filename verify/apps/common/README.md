# verify/common 裸机 C 运行环境

`verify/common` 提供 LoongArch 验证应用共用的裸机 C 执行环境，面向 `verify/apps` 下的 hello、coremark 类程序。应用侧只需要选择 `LA_PROFILE`，公共库、启动文件、链接脚本和工具链前缀由 common 层统一管理。

## 目录组织

- `crt/start.S`：复位入口，初始化通用寄存器、DMW、CSR，选择每 hart 私有栈，调用
  `la_runtime_init(hart_id)` 后进入 `main()`。
- `include/`：新的公共接口，统一使用 `la_*` 命名，如 `la_io.h`、`la_timer.h`、`la_runtime.h`、`la_heap.h`。
- `lib/`：运行时实现，包括 console 输出、timer、bss/init array 初始化、heap、系统调用桩和 assert。
- `clib/`：轻量 C 库与旧应用兼容头，包括 `string.*`、`config.h`、`timer.h`、`uart.*`。
- `newlib_wrap/`：轻量 `printf`/`snprintf`/`vasprintf` 实现。
- `mk/toolchain.mk`：统一 32/64 工具链选择。
- `mk/common.mk`：统一公共库与 `start.o` 构建规则。
- `linker.script`：裸机链接布局，提供 bss、stack、heap、init/fini array 等符号。

## 应用接入

应用 Makefile 推荐按下面的顺序接入：

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

构建时通过 `LA_PROFILE` 选择目标：

```sh
make -C verify/apps/coremark LA_PROFILE=la32r
make -C verify/apps/coremark LA_PROFILE=la64
```

## 运行时能力

- C 入口：`_start -> la_runtime_init(hart_id) -> main -> exit`。
- 多核启动：最多四个 hart 各有 8 KiB 私有栈；hart0 独占 `.bss` 和 init/fini array，secondary
  通过带 `dbar` 的 ready barrier 等待共享初始化完成。
- 内存初始化：hart0 启动阶段清零 `.bss`，执行 `.preinit_array/.init_array`，退出时执行
  `.fini_array`。
- heap：提供简单 bump allocator，支持 `malloc/calloc/realloc/free/strdup/sbrk`。
- IO：`printf` 最终通过 `fputc()` 写入仿真 console MMIO 地址。
- timer：LA64 使用 `rdtime.d`，LA32R 使用 `rdtimel.w` 读取硬件计数器。
- syscall 桩：提供 `_write/_read/_sbrk/_exit/_fstat/_isatty/gettimeofday` 等常见裸机兼容接口。
- assert：提供 `LA_ASSERT()`、`__assert_fail()`、`__assert_func()`。

## 命名约定

公共接口统一使用 `la_*` 前缀。旧的外部项目命名和接口已从 common 源码中移除，避免和其它项目或第三方 SDK 产生归属和符号冲突。

## 注意事项

- 当前 heap 位于 `.stack` 之后、`.dymmy_exit` 之前，空间由 `linker.script` 中的 `_heap_start/_heap_end` 控制。
- `free()` 目前是 no-op，适合验证程序和短生命周期裸机应用；需要长期运行的应用应扩展 allocator。
- `linker.script` 使用 PHDRS 将代码只读段映射为 `R E` LOAD，将数据、bss、stack 和仿真退出段映射为 `RW` LOAD。
