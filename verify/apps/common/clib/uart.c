#include "uart.h"

#include "la_mmio.h"

/* Line control and line status bits for the simple UART model. */
#define LA_LCR_SET_DLAB 0x80U
#define LA_LCR_PARITY_ENABLE 0x08U
#define LA_LCR_PARITY_EVEN 0x10U
#define LA_LCR_WORD_SIZE_MASK 0x03U
#define LA_LCR_STOP_BIT2 0x04U
#define LA_LSR_TX_EMPTY 0x20U
#define LA_LSR_IDLE 0x40U

/* Convert a UART register offset into an absolute MMIO address. */
static uintptr_t la_uart_reg(const la_uart_device_t *uart, uint32_t reg)
{
    return uart->register_map + reg;
}

/* Program the UART divisor latch for the requested baud rate. */
static void la_uart_set_baudrate(la_uart_device_t *uart, uint32_t baudrate)
{
    uint32_t baud_div = (uint32_t)((LA_APB_FREQ_HZ / baudrate) >> 4);
    uint8_t lcr = la_mmio_read8(la_uart_reg(uart, LA_UART_LCR));

    /* Divisor latch registers are only accessible while DLAB is set. */
    uart->baudrate = baudrate;
    la_mmio_write8(la_uart_reg(uart, LA_UART_LCR), lcr | LA_LCR_SET_DLAB);
    la_mmio_write8(la_uart_reg(uart, LA_UART_DLL), (uint8_t)(baud_div & 0xffU));
    la_mmio_write8(la_uart_reg(uart, LA_UART_DLH), (uint8_t)((baud_div >> 8) & 0xffU));
    la_mmio_write8(la_uart_reg(uart, LA_UART_LCR), lcr & (uint8_t)~LA_LCR_SET_DLAB);
}

/* Program word size, stop bit, and parity settings. */
static void la_uart_set_line_control(la_uart_device_t *uart, const la_uart_config_t *config)
{
    uint8_t lcr = 0;

    /* Encode word length, stop bit, and parity into the UART LCR register. */
    switch (config->wordsize) {
    case LA_UART_WORDSIZE_5:
        lcr |= 0U;
        break;
    case LA_UART_WORDSIZE_6:
        lcr |= 1U;
        break;
    case LA_UART_WORDSIZE_7:
        lcr |= 2U;
        break;
    case LA_UART_WORDSIZE_8:
    default:
        lcr |= 3U;
        break;
    }

    if (config->stopbit == LA_UART_STOPBIT_2) {
        lcr |= LA_LCR_STOP_BIT2;
    }

    if (config->parity != LA_UART_PARITY_NONE) {
        lcr |= LA_LCR_PARITY_ENABLE;
        if (config->parity == LA_UART_PARITY_EVEN) {
            lcr |= LA_LCR_PARITY_EVEN;
        }
    }

    lcr &= (uint8_t)(LA_LCR_WORD_SIZE_MASK | LA_LCR_STOP_BIT2 | LA_LCR_PARITY_ENABLE | LA_LCR_PARITY_EVEN);
    la_mmio_write8(la_uart_reg(uart, LA_UART_LCR), lcr);
}

/* Bind a device handle to a UART instance in the verification SoC. */
uint32_t la_uart_open(la_uart_device_t *uart, uint32_t id)
{
    /* The verification SoC currently exposes one UART instance. */
    if (id != 0U) {
        return 1U;
    }

    uart->uart_id = 0U;
    uart->register_map = LA_UART0_BASE;
    return 0U;
}

/* Apply a complete UART configuration to an opened device. */
uint32_t la_uart_init(la_uart_device_t *uart, const la_uart_config_t *config)
{
    if (uart->register_map == 0U) {
        return 1U;
    }

    la_uart_set_baudrate(uart, config->baudrate);
    la_uart_set_line_control(uart, config);
    uart->parity = config->parity;
    uart->stopbit = config->stopbit;
    uart->wordsize = config->wordsize;
    uart->rxmode = config->rxmode;
    uart->txmode = config->txmode;
    return 0U;
}

/* Mark a UART handle as closed and disable software TX/RX modes. */
uint32_t la_uart_close(la_uart_device_t *uart)
{
    uart->rxmode = LA_UART_DISABLE;
    uart->txmode = LA_UART_DISABLE;
    uart->uart_id = UINT32_MAX;
    uart->register_map = 0U;
    return 0U;
}

/* Poll until the transmitter is ready and send one character. */
uint32_t la_uart_putc(la_uart_device_t *uart, uint8_t c)
{
    if (uart->txmode == LA_UART_DISABLE) {
        return 1U;
    }

    /* Polling transmit keeps the driver deterministic for bare-metal tests. */
    while ((la_mmio_read8(la_uart_reg(uart, LA_UART_LSR)) & LA_LSR_TX_EMPTY) == 0U) {
    }

    la_mmio_write8(la_uart_reg(uart, LA_UART_THR), c);
    return 0U;
}

/* Return 0 when the UART reports idle, 1 when it is still busy. */
uint32_t la_uart_status(la_uart_device_t *uart)
{
    uint8_t lsr = la_mmio_read8(la_uart_reg(uart, LA_UART_LSR));
    return (lsr & LA_LSR_IDLE) != 0U ? 0U : 1U;
}
