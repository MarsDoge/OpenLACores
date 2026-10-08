// ------------------------------------------------------------------------------------//
//  Copyright (c) 2026 Loongson Technology Corporation Limited.
//
//  OpenLACores is licensed under Mulan PSL v2.
// 
//  You can use this software according to the terms and conditions of the Mulan PSL v2.
//
//  You may obtain a copy of Mulan PSL v2 at:
//           http://license.coscl.org.cn/MulanPSL2
// 
//  THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY
//  KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
//  NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// 
//  See the Mulan PSL v2 for more details.
// ------------------------------------------------------------------------------------//

typedef unsigned int  uint32_t;
typedef unsigned char uint8_t;
typedef unsigned int  uintptr_t;

#define UART_BASE              0x1fe00000U
#define UART_THR               (UART_BASE + 0U)
#define UART_INTERRUPT_ENABLE  (UART_BASE + 4U)
#define UART_FIFO_CONTROL      (UART_BASE + 8U)
#define UART_LINE_CONTROL      (UART_BASE + 12U)
#define UART_MODEM_CONTROL     (UART_BASE + 16U)
#define UART_LINE_STATUS       (UART_BASE + 20U)
#define UART_DLAB_LSB          (UART_BASE + 0U)
#define UART_DLAB_MSB          (UART_BASE + 4U)

static void write_reg_u8(uintptr_t address, uint8_t value)
{
    *(volatile uint8_t *)address = value;
}

static uint8_t read_reg_u8(uintptr_t address)
{
    return *(volatile uint8_t *)address;
}

static void write_serial(char value)
{
    while ((read_reg_u8(UART_LINE_STATUS) & 0x20U) == 0U) {
    }

    write_reg_u8(UART_THR, (uint8_t)value);
}

static void init_uart(uint32_t frequency_hz, uint32_t baud_rate)
{
    uint32_t divisor = frequency_hz / (baud_rate << 4);

    write_reg_u8(UART_INTERRUPT_ENABLE, 0x00U);
    write_reg_u8(UART_LINE_CONTROL, 0x80U);
    write_reg_u8(UART_DLAB_LSB, (uint8_t)divisor);
    write_reg_u8(UART_DLAB_MSB, (uint8_t)(divisor >> 8));
    write_reg_u8(UART_LINE_CONTROL, 0x03U);
    write_reg_u8(UART_FIFO_CONTROL, 0xc7U);
    write_reg_u8(UART_MODEM_CONTROL, 0x20U);
}

static void uart_print(const char *text)
{
    while (*text != '\0') {
        write_serial(*text);
        ++text;
    }
}

void boot_uart_init(void)
{
    init_uart(100000000U, 115200U);
    uart_print("\r\nOpenLA132S: start LA32 Linux kernel\r\n");
}
