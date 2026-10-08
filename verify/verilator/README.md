# OpenLACores Verilator 仿真环境

该目录提供一个独立的 Verilator 仿真器。它直接例化 RTL 代码顶层，比如`openla132_ip_top`，不依赖其他仿真顶层、生成总线
模型或 C++ 运行框架。

## 组成

- `vsrc/verilator_top.sv`：保留 CPU 原生 32 位 AXI 接口，并导出稳定的写回探针。
- `vsrc/soc_config.vh`：定义本地指令/数据 SRAM 窗口和串口 MMIO 地址。
- `vsrc/sram/openla132_spram_bytemask_init.v`：可由仿真器初始化的字节写 SRAM 模型。
- `src/axi.cpp`：支持多 outstanding ID 和 burst 的 32 位 AXI 从设备。
- `src/ram.cpp`：按需分配页面的稀疏内存模型。
- `src/uart.cpp`：地址为 `0x1fe00000` 的最小 16550 UART 模型。
- `src/elf_load.cpp`：ELF32/ELF64 LoongArch 与 raw binary 加载器，自动清零 `PT_LOAD` 的 BSS。
- `src/ref_proxy.cpp`：通过 `dlopen` 调用 loong-emu DiffTest ABI。
- `src/difftest.cpp`、`src/check.cpp`：与处理器无关的提交执行及体系结构状态比较。
- `src/diff_micro.cpp`：OpenLA132 的多微操作指令、实现相关 CSR、计时器及异常边界策略。
- `src/checkpoint.cpp`：保存并恢复 RTL、AXI、RAM、UART、DiffTest 和参考模型状态。
- `src/verilator_main.cpp`：时钟、复位、波形、退出标记和统计控制。

## 构建

先准备参考模型：

```bash
make -C verify/loong-emu DIFF=1
```

构建 Verilator 仿真器：

```bash
make -C verify/verilator
```

构建产物名称包含 MMU 和 SRAM 两个配置，例如默认的
`verify/verilator/build/emu-mmu1-sram0` 以及本地 SRAM 版本
`verify/verilator/build/emu-mmu0-sram1`。每组配置使用独立的 Verilator 对象目录。

```bash
make -C verify/verilator CONFIG_MMU=1
make -C verify/verilator CONFIG_MMU=0
make -C verify/verilator CONFIG_MMU=0 CONFIG_SRAM=1
```

## 运行

默认开启 DiffTest：

```bash
verify/verilator/build/emu-mmu1-sram0 \
  --diff \
  --image verify/apps/coremark/coremark.exe
```

关闭 DiffTest，仅运行 RTL、AXI 内存和串口模型：

```bash
verify/verilator/build/emu-mmu1-sram0 \
  --no-diff \
  --image verify/apps/coremark/coremark.exe
```

也可以使用 Makefile 快捷目标：

```bash
make -C verify/verilator run
make -C verify/verilator run-nodiff
make -C verify/verilator run-coremark-sram
make -C verify/verilator run-rtthread-sram
make -C verify/verilator run-rtthread-axi
```

`run-coremark-sram` 使用 `CONFIG_MMU=0 CONFIG_SRAM=1`，指令和数据访问走
`inst_sram_*`/`data_sram_*` 接口，不走系统 AXI 存储路径。

RT-Thread Nano 源码作为本地验证依赖放在 `verify/kernel/RTThread_Nano`；
`run-rtthread-sram` 会先构建该目录，再以同样的
`CONFIG_MMU=0 CONFIG_SRAM=1` 配置启动 RT-Thread。仿真顶层将 ELF 的
`0x1c000000` 指令段和 `0x15000000` 数据段分别装入两组 SRAM，
系统节拍使用 CPU 内部 CSR 定时器，不驱动 `ext_int`。该目标构建独立的
`obj/sram/RTThread_Nano.elf`，并使用 `HAS_CACHE=0`。

`run-rtthread-axi` 同样先构建 RT-Thread，然后固定使用
`CONFIG_MMU=1 CONFIG_SRAM=0`，通过系统 AXI 接口访问内存和仿真外设。
该目标构建独立的 `obj/axi/RTThread_Nano.elf`，并使用 `HAS_CACHE=1`，使
启动代码将普通内存配置为 cached，与 RTL 中启用的 ICache/DCache 一致。

当 `IMAGE` 的文件名为 `coremark.exe` 时，`run` 和 `run-nodiff` 会自动将周期
上限设置为 `2G`，以满足 3000 次迭代的有效 CoreMark 长跑。可以通过
`COREMARK_MAX_CYCLES=N` 调整；`RUN_ARGS` 中显式给出的 `--max-cycles` 优先。

常用参数：

- `--diff` / `--no-diff`：开启或关闭参考模型比对，默认开启。
- `--ref FILE`：指定参考模型，默认使用 `verify/loong-emu/build/la_emu_ref.so`。
- `--ref-arch NAME`：参考 CPU 类型，默认 `loongarch32s`。
- `--cpu-model NAME`：选择微架构 Diff 策略，默认 `la132`。
- `--ram-size SIZE`：RAM 物理地址窗口，默认 `512M`。
- `--boot-pc ADDR`：覆盖 ELF 入口地址。
- `--load-address ADDR`：raw binary 加载地址，默认 `0x1c000000`。
- `--load FILE@ADDR`：额外预加载 ELF 或 raw 镜像，可重复指定。
- `--max-cycles N` / `--max-commits N`：设置运行上限。
- `--trace FILE`：输出 VCD 波形。
- `--commit-log`：打印每条提交指令及 GPR 写回。
- `--quiet-uart`：保留 UART 输出但不打印到终端。
- `--checkpoint FILE`：周期性保存可恢复的完整仿真状态，并在退出时再保存一次。
- `--checkpoint-interval N`：checkpoint 周期，默认 1000 万个时钟周期。
- `--restore FILE`：从 checkpoint 恢复；可不再指定初始镜像。

数值参数支持十进制、`0x` 十六进制以及 `K`、`M`、`G` 后缀。
ELF64 中的 LoongArch DMW 地址按低 32 位映射到当前 LA132 的物理地址空间；
超出 4GiB 的段会直接报错，不做静默截断。

## 退出与检查范围

仿真器从 `verify/apps/common/include/la_config.h` 读取退出标记；当前在提交
`addi.w $r0, $r0, 52`（`0x0280d000`）时报告 `GOOD TRAP`。应用和仿真器
共用同一配置，修改标记后会自动同步。`--max-commits` 达到上限也作为受控
成功退出，便于短回归测试。

通用 Diff 框架负责检查提交 PC、执行参考指令并比较全部 GPR 的低 32 位。LA132 的
`rdcnt*` 双微操作提交、`CPUCFG`、调试 CSR、实时计时器以及中断/异常边界全部由
`DiffMicro` 派生实现处理，不混入通用执行框架。增加其他 CPU 时，实现新的
`DiffMicro` 派生类并在 `make_diff_micro()` 中注册即可。

运行快速检查：

```bash
make -C verify/verilator test
```
