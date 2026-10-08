#	OpenLA132 IBUS/DBUS接口

IBUS/DBUS 为SRAM接口，需外接ISRAM/DSRAM。

I-BUS、D-BUS 其实是对等可互换的，通常 ISRAM 存放指令，DSRAM 存放数据。但其实指令访问也可以访问 DSRAM，数据访问也可以访问 ISRAM。

##	自定义带握手 SRAM 接口

自定义 SRAM 接口信号定义如下，其中 ack、rrdy 为握手信号，可配置为有或无。

**自定义 SRAM 接口信号描述**

| 名称 | 宽度 | 方向 | 描述 |
| --- | --- | --- | --- |
| clk | 1 | —>mster/slave | 时钟 |
| en | 1 | —>slave | 使能信号，片选作用，高有效 |
| strb | 4 | —>slave | 字节选通信号，高有效 |
| wr | 1 | —>slave | 写使能，高有效 |
| fetch | 1 | —>slave | 取指指示位。1表示是取指请求，0表示是访存请求。 |
| addr | 32 | —slave | 地址，读写均使用同一地址线 |
| wdata | 32 | —>slave | 写数据 |
| rdata | 32 | slave—> | 读数据 |
| ack | 1 | slave—> | 读地址，写地址和数据的接收握手，高有效 |
| rrdy | 1 | slave—> | 读数据的返回握手，高有效 |

需要注意，地址信号(addr)是字节寻址的，其指向读写数据的最低有效位。因而addr和strb信号需配合使用，不支持3字节读写，有且只有以下类型组合。

| addr[1:0]=2'b00时，可能的组合：strb=4'b0001, strb=4'b0011, strb=4'b1100, strb=4'b1111addr[1:0]=2'b01时，可能的组合：strb=4'b0010addr[1:0]=2'b10时，可能的组合：strb=4'b0100, strb=4'b1100addr[1:0]=2'b11时，可能的组合： strb=4'b1000 |
| --- |

wdata和rdata有效数据字节也与strb信号对应，小尾端下，配合如下：

**自定义 SRAM 接口 `strb` 信号描述**

|  | data[31:24] | data[23:16] | data[15:8] | data[7:0] |
| --- | --- | --- | --- | --- |
| strb=4’b0001 | - | - | - | valid |
| strb=4’b0010 | - | - | valid | - |
| strb=4’b0100 | - | valid | - | - |
| strb=4’b0001 | valid | - | - | - |
| strb=4’b0011 | - | - | valid | valid |
| strb=4’b1100 | valid | valid | - | - |
| strb=4’b1111 | valid | valid | valid | valid |

##	读写时序图

其读一个半字的时序逻辑如下：

**自定义 SRAM 接口读一个半字的时序**

![自定义 SRAM 接口读半字时序](OpenLA132_Integration_Guide_assets/image6.emf)

其写一个字节的时序逻辑如下：

**自定义 SRAM 接口写一个字节的时序**

![自定义 SRAM 接口写字节时序](OpenLA132_Integration_Guide_assets/image7.emf)

连续读-写时序图如下：

**自定义 SRAM 接口连续读写时序**

![自定义 SRAM 接口连续读写时序](OpenLA132_Integration_Guide_assets/image8.emf)

##	注意事项

ack既作为读请求命令的响应，也作为写请求命令和数据的响应。可以认为wdata属于写命令。

rrdy握手信号只对读操作有效，在返回读数据时置起。

Master不会发出非对齐的请求。

Master端置起请求（en为1），但是没有收到ack，则可能会更改请求，比如addr被更改。

Strb信号通常用为写选通，但对于读请求，其也指示了master期待读回的数据。对于未被选通的字节，slave可以返回任意值。

在master无请求时，slave可以常置ack。只有在en有效且ack为1时，才是完成一个请求命令传输。

在master无数据等待返回时，slave可以常置rrdy。Master在无等待数据时，收到rrdy并不会出错。

所有读写，握手失败的周期可以是0个到任意个clock，但对一次读或写操作，握手成功只会持续1个clock。

# OpenLA132 SYSBUS接口

SYSBUS 为 AXI3 接口，数据位宽可静态配置为 32/64/128 位，不支持总线错响应。

##	AXI 接口说明

在 OpenLA132 配置选为无 CACHE 时，不支持 burst 传输，对应 burst 固定为2’b01，对应 length 固定为4’b0000。

在 OpenLA132 配置选为有 CACHE 时，需要 AXI 支持 burst 传输。一个 burst 传输固定为32字节，且在 burst 传输时，读数据采用 wrap 传输，写数据采用 increment 传输。

以配置了 CACHE 情况下 32 位 AXI 为例，各信号列举如下：

**支持 Cache 时 64 位 AXI3 接口描述**

| 信号 | 位宽 | 方向 | 描述（含 OpenLA132 的信号特殊性） |
| --- | --- | --- | --- |
| AXI时钟与复位信号 |  |  |  |
| aclk | 1 | input | AXI时钟 |
| aresetn | 1 | input | AXI复位，低电平有效 |
| 读请求地址通道 |  |  |  |
| arid | [3:0] | master—>slave | 读请求的ID号，fetch为4’b0001，load为4’b0000 |
| araddr | [31:0] | master—>slave | 读请求的地址 |
| arlen | [3:0] | master—>slave | 请求传输的长度，4’b0000或4’b0111 |
| arsize | [2:0] | master—>slave | 请求传输的大小，只可能为3’b000，3’b001，3’b010 |
| arburst | [1:0] | master—>slave | 传输类型，为2’b01或2’b10 |
| arlock | [1:0] | master—>slave | 原子锁，不使用，固定为2’ b00 |
| arcache | [3:0] | master—>slave | CACHE属性，只可能为4’b0000，4’b0010，表示cacheable或Noncacheable |
| arprot | [2:0] | master—>slave | 保护属性，只可能为3’b010，3’b110，表示取指或数据访问 |
| arvalid | 1 | master—>slave | 读请求地址握手信号，读请求地址有效 |
| arready | 1 | slave—>master | 读请求地址握手信号，slave端准备好接受地址传输 |
| 读请求数据通道 |  |  |  |
| rid | [3:0] | slave—>master | 读请求的ID号，slave端应对应回4’b0000或4’b0001 |
| rdata | [31:0] | slave—>master | 读请求的读回数据 |
| rresp | [1:0] | slave—>master | 本次读请求是否成功完成，CPU默认都是传输成功 |
| rlast | 1 | slave—>master | 本次读请求的最后一拍数据的指示信号，slave应固定回1 |
| rvalid | 1 | slave—>master | 读请求数据握手信号，读请求数据有效 |
| rready | 1 | master—>slave | 读请求数据握手信号，master端准备好接受数据传输 |
| 写请求地址通道 |  |  |  |
| awid | [3:0] | master—>slave | 写请求的ID号，取值范围取决于openLA132_define.h里的宏定义“OPEN132_N_AXI_WID” |
| awaddr | [31:0] | master—>slave | 写请求的地址 |
| awlen | [3:0] | master—>slave | 请求传输的长度，4’b0000或4’b0111 |
| awsize | [2:0] | master—>slave | 请求传输的大小，只可能为3’b000，3’b001，3’b010 |
| awburst | [1:0] | master—>slave | 传输类型，固定为2’b01 |
| awlock | [1:0] | master—>slave | 原子锁，不使用，固定为2’b00 |
| awcache | [3:0] | master—>slave | CACHE属性，只可能为4’b0000，4’b0010，表示cacheable或Noncacheable |
| awprot | [2:0] | master—>slave | 保护属性，只可能为3’b010，3’b110，表示取指或数据访问 |
| awvalid | 1 | master—>slave | 写请求地址握手信号，写请求地址有效 |
| awready | 1 | slave—>master | 写请求地址握手信号，slave端准备好接受地址传输 |
| 写请求数据通道 |  |  |  |
| wid | [3:0] | master—>slave | 写请求的ID号，取值范围同awid |
| wdata | [31:0] | master—>slave | 写请求的写数据 |
| wstrb | [3:0] | master—>slave | 写请求控制信号，字节选通位 |
| wlast | 1 | master—>slave | 写请求控制信号，固定为1 |
| wvalid | 1 | master—>slave | 写请求数据握手信号，写请求数据有效 |
| wready | 1 | slave—>master | 写请求数据握手信号，slave端准备好接受数据传输 |
| 写请求响应通道 |  |  |  |
| bid | [3:0] | slave—>master | 写请求的ID号，取值范围同awid |
| bresp | [1:0] | slave—>master | 写请求控制信号，CPU默认都是传输成功 |
| bvalid | 1 | slave—>master | 写请求响应握手信号，写请求响应有效 |
| bready | 1 | master—>slave | 写请求响应握手信号，master端准备好接受写响应 |

##	读写通道请求组合枚举

对写请求，CPU发出来的 awsize/awaddr和wstrb 是严格一致对应的，针对32位AXI有且只有以下组合：

**32 位 AXI 的写通道组合情况列举**

| awburst | awlen[3:0] | awsize[2:0 | awaddr[4:0] | wstrb[7:0] | Data valid width | 访问类型 |
| --- | --- | --- | --- | --- | --- | --- |
| 2'b01 | 4'b0111 | 3'b010 | 5'b00000 | 4'b1111 | 32bit | Incr访问32字节 |
|  | 4'b0000 | 3'b010 | 5'bxxx00 | 4'b1111 | 32bit | 单次访问 |
|  |  | 3'b001 | 5'bxxx00 | 4'b0011 | 16bit |  |
|  |  |  | 5'bxxx10 | 4'b1100 |  |  |
|  |  | 3'b000 | 5'bxxx00 | 4'b0001 | 8bit |  |
|  |  |  | 5'bxxx01 | 4'b0010 |  |  |
|  |  |  | 5'bxxx10 | 4'b0100 |  |  |
|  |  |  | 5'bxxx11 | 4'b1000 |  |  |

**32 位 AXI 的读通道组合情况列举**

| arburst | arlen[3:0] | arsize[2:0 | araddr[4:0] | Data valid width | 访问类型 |
| --- | --- | --- | --- | --- | --- |
| 2’b10 | 4'b0111 | 3'b010 | 5'bxxx00 | 32bit | Wrap访问32字节 |
| 2’b01 | 4’b0000 | 3'b010 | 5'bxxx00 | 32bit | 单次访问 |
|  |  | 3'b001 | 5'bxxx00 | 16bit |  |
|  |  |  | 5'bxxx10 |  |  |
|  |  | 3'b000 | 5'bxxx00 | 8bit |  |
|  |  |  | 5'bxxx01 |  |  |
|  |  |  | 5'bxxx10 |  |  |
|  |  |  | 5'bxxx11 |  |  |

##	读写同地址说明

OpenLA132 作为AXI的Master，不会发出对同一地址写后读的请求。也就是说，当发出对地址A的写请求后，在 bvalid 位回来前，不会发出对地址A的读请求。

但是 OpenLA132 可能发出对同一地址读后写的请求。也就是说，当发出对地址A的读请求后，在rvalid位回来前，可能发出对地址A的写请求。但这时，slave返回的数据是写之前或写之后的，CPU都可以获得正确的读数据。

总结，OpenLA132 在 master 端确保了同一地址的读写乱序问题，不需要slave完成同地址定序。

##	outstanding 同 ID 请求说明

outstanding 同ID请求是指：在发出某一ID的读（写）请求后，在未收到rvalid（bvalid）前又发出了同一ID的下一个读（写）请求。

OpenLA132 在写通道上，不会出现outstanding的同ID请求。

OpenLA132 在读通道上，需要依据是否配置有Cache选择：

在配置具有 ICACHE，也具有 DCACHE 时，不会发出outstanding的同ID读请求。

在配置无 ICACHE 或无 DCACHE 时，用户可在 openLA132_define.h里配置是否允许发出 outstanding 的同ID读请求（指定宏OPEN132_AXI_NO_SAME_ID则表示不允许发出outstanding的同ID读请求）。

一旦配置了允许 CPU 发出 outstanding 的同ID读请求。则对于同ID的请求，slave 应当按请求顺序返回数据。

##	Outstanding 支持数

OpenLA132 在写通道（aw、w和b通道）上最多会发出4个 Outstanding的写请求，并且 Outstanding请求的 WID/WID 不同，范围是0~3。

OpenLA132 在读通道（ar和r通道）上，会发出两个 outsanding 的请求，对应ID分别为0、1，也就是fetch和load各一个。

##	Cache 配置下 AXI 注意事项

OpenLA132 Cache行为 32 字节，对 32 位AXI，所有 burst 的读写传输 length 都是7，size 都是2（4字节）。

读 burst 类型固定为 Wrap，即使发出的 araddr 是32字节对齐的，burst 类型也是 Wrap。

写 burst 类型固定为 Incr，故 burst 发出的 awaddr 是32字节对齐的。

OpenLA132 不会发出非对齐的 `addr`、`size` 和 `strb` 请求，各类组合情况参见 2.6.2 节。

##	IP 时钟域说明

OpenLA132 处理器IP分为2个时钟域：clk 和jtag_tck/cjtag_tckc。

clk时钟域：IP最主要的时钟域，绝大多数逻辑都处在这个时钟域中。这个时钟的频率对应通常意义上所说的处理器主频。

jtag_tck/cjtag_tckc 时钟域：处理器中JTAG TAP控制器部分所用的时钟。这个时钟直接来自于芯片的 JTAG TCK 时钟输入。它的频率不需要很高，通常不高于50MHz。

上述两个时钟域彼此间为纯异步关系。