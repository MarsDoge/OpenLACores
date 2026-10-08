#	OpenLA132 工艺相关单元替换

OpenLA132 处理器IP中需要进行替换的工艺相关单元主要分为两类：一类是时钟门控、时钟多路选择器这两种单元；另一类是SRAM宏单元（如果配置了Cache）。


上述单元的接口及功能行为请见 design/sys/openla132/libwrapper 目录下, openLA132_std_cell_cg.v、openLA132_std_cell_cmux2.v、openLA132_spram.v、openLA132_spram_bitmask.v和 openLA132_spram_bytemask.v 文件中的模拟实现代码。

需要说明的一点是：OpenLA132 处理器 IP 设计不依赖与 RAM 的Q端输出读保持功能，因此在 SRAM 的功能模拟实现代码中，故意将 RAM 的 Q 端输出在非读请求下一周期的时候置为随机值，用户在替换 SRAM 宏单元时无需理会此功能。