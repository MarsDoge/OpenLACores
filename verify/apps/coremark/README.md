#	CoreMark

CoreMark 提供一项仅测试处理器核心功能的基准测试。有关 EEMBC 的完整嵌入式基准测试套件，请参阅 www.eembc.org。

若需要计算密度更高的 CoreMark 版本——来自常见应用程序的执行循环的更大的数据集——请参阅同样托管在 GitHub 上的 EEMBC [CoreMark-PRO](https://www.github.com/eembc/coremark-pro) 基准测试。

## 交叉编译、构建

执行：

~~~
make CROSS_COMPILE=</path/to/cross_compile> -j<thread>
~~~


## 日志文件格式

日志文件格式如下：

~~~
2K performance run parameters for coremark.    (运行类型)
CoreMark Size       : 666                    (缓冲区大小)
Total ticks         : 25875                  (平台相关数值)
Total time (secs)   : 25.875000              (实际执行时间，单位：秒)
Iterations/Sec      : 3864.734300            (需要报告的性能数值)
Iterations          : 100000                 (使用的迭代次数)
Compiler version    : GCC3.4.4               (编译器及其版本)
Compiler flags      : -O2                    (编译器和链接器选项)
Memory location     : Code in flash, data in on chip RAM
seedcrc             : 0xe9f5                 (输入种子的标识符)
[0]crclist          : 0xe714                 (链表部分的校验值)
[0]crcmatrix        : 0x1fd7                 (矩阵部分的校验值)
[0]crcstate         : 0x8e3a                 (状态机部分的校验值)
[0]crcfinal         : 0x33ff                 (与迭代次数相关的输出)
Correct operation validated. See README.md for run and reporting rules.  (仅在运行成功时出现)
CoreMark 1.0 : 6508.490622 / GCC3.4.4 -O2 / Heap             (仅在成功的性能运行中出现)
~~~

其中 `Memory location` 一行表示代码位于 Flash、数据位于片上 RAM。

## 版权

Copyright © 2009 EEMBC，保留所有权利。

CoreMark 是 EEMBC 的商标；EEMBC 是 Embedded Microprocessor Benchmark Consortium 的注册商标。
