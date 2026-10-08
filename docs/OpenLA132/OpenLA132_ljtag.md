#	OpenLA132 LJTAG 接口介绍

OpenLA132 处理器 IP 含有兼容 JTAG 协议的调试接口。

##	LJTAG调试接口

OpenLA132 的 LJTAG 调试接口支持标准5线模式（jtag）和精简的2线模式（cjtag），通过cjtag_sel输入引脚进行选择。

**LJTAG 接口信号说明**

| 名称 | 方向 | 位宽 | 集成相关说明 |
| --- | --- | --- | --- |
| cjtag_sel | IN | 1 | 标准5线模式（jtag）和精简的2线模式（cjtag）的模式配置引脚。输入0为5线模式，输入1为2线模式。该引脚输入信号在上电后应保持不变。 |
| cjtag_trstn | IN | 1 | cjtag的异步复位信号，低电平有效。强烈建议接入上电复位（Power On Reset）。 |
| cjtag_clk | IN | 1 | cjtag的采样用时钟。该时钟在cjtag复位使用期间应保持稳定，且其频率至少是cjtag_tckc的5倍以上。该时钟与cjtag_tckc是完全异步的关系。 |
| cjtag_tckc | IN | 1 | 2线jtag的TCKC引脚的输入。 |
| cjtag_tmsc_i | IN | 1 | 2线jtag的TMSC引脚的输入。 |
| cjtag_tmsc_o | OUT | 1 | 2线jtag的TMSC引脚的输出。 |
| cjtag_tmsc_oe | OUT | 1 | 2线jtag的TMSC引脚的输出使能，高有效。 |
| jtag_tck | IN | 1 | 5线jtag调试接口时钟。应连接至芯片的ljtag_tck输入引脚。 |
| jtag_trst | IN | 1 | 5线jtag调试接口复位信号，低电平有效。应连接至芯片的ljtag_trst输入引脚。该复位信号尽管是异步复位信号，但是会在IP内部使用ljtag_tck时钟进行同步释放处理，所以该复位信号置有效并撤销的过程中ljtag_tck端口需要输入时钟 |
| jtag_tdi | IN | 1 | 5线jtag调试接口输入数据。应连接至芯片的ljtag_tdi输入引脚。 |
| jtag_tdo | OUT | 1 | 5线jtag调试接口输出数据。应连接至芯片的ljtag_tdo输入引脚。 |
| jtag_tms | IN | 1 | 5线jtag调试接口模式选择控制信号。应连接至芯片的ljtag_tms输入引脚。 |

