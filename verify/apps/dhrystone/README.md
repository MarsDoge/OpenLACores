#	Dhrystone 2.1

本目录包含 Reinhold P. Weicker 的 Dhrystone 2.1 源码，并已适配 OpenLA132S 裸机运行时环境。基准测试源码保留 GNU89 的 K&R 语法；共用运行时仍采用 C99。

默认的 10,000 次运行构建用于功能正确性验证和微架构性能分析。它使用由 `rdtime` 支持、频率为 100 MHz 的周期计时器，但运行时间短于 Dhrystone 标准评分要求的两秒阈值，因此其结果不能作为标准 Dhrystone 分数发布。

使用交叉编译器编译严格的单核性能分析程序：

```sh
make CROSS_COMPILE=</path/to/cross_compile> -j<thread>
```

评分换算公式为：

```text
Dhrystones/s = frequency_hz * runs / measured_loop_ticks
DMIPS         = Dhrystones/s / 1757
DMIPS/MHz     = DMIPS / (frequency_hz / 1e6)
```

计算时只能使用基准程序打印的循环计时器增量；模拟器从复位到 trap 的周期计数还包含初始化和输出过程，不能用于上述公式。
